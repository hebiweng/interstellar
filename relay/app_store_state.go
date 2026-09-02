package main

import (
	"database/sql"
	"errors"
	"time"
)

type storedSubscription struct {
	UserID                string
	OriginalTransactionID string
	Environment           string
}

type processedAppStoreNotification struct {
	UUID                  string
	Type                  string
	Subtype               string
	Environment           string
	TransactionID         string
	OriginalTransactionID string
}

func (s *Store) ListSubscriptionsForReconciliation() ([]storedSubscription, error) {
	rows, err := s.db.Query(`SELECT s.user_id,s.original_transaction_id,s.environment
		FROM subscriptions s JOIN commerce_users u ON u.user_id=s.user_id
		WHERE u.account_status='active' ORDER BY s.updated_at ASC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var items []storedSubscription
	for rows.Next() {
		var item storedSubscription
		if err := rows.Scan(&item.UserID, &item.OriginalTransactionID, &item.Environment); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (s *Store) AppStoreNotificationProcessed(notificationUUID string) (bool, error) {
	var value int
	err := s.db.QueryRow(`SELECT 1 FROM app_store_notifications WHERE notification_uuid=?`, notificationUUID).Scan(&value)
	if errors.Is(err, sql.ErrNoRows) {
		return false, nil
	}
	return err == nil, err
}

func (s *Store) RecordAppStoreNotification(item processedAppStoreNotification) error {
	_, err := s.db.Exec(`INSERT OR IGNORE INTO app_store_notifications
		(notification_uuid,notification_type,subtype,environment,transaction_id,original_transaction_id,received_at)
		VALUES(?,?,?,?,?,?,?)`, item.UUID, item.Type, item.Subtype, item.Environment,
		item.TransactionID, item.OriginalTransactionID, time.Now().UTC().Format(time.RFC3339))
	return err
}
