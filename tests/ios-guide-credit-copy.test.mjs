import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";

const root = path.resolve(import.meta.dirname, "..");
const translations = JSON.parse(
  fs.readFileSync(
    path.join(root, "ios", "Localization", "UI", "commerce-onboarding.json"),
    "utf8",
  ),
);
const storeKit = JSON.parse(
  fs.readFileSync(path.join(root, "ios", "App", "Interstellar.storekit"), "utf8"),
);
const legalTranslations = JSON.parse(
  fs.readFileSync(
    path.join(root, "ios", "Localization", "UI", "legal-license.json"),
    "utf8",
  ),
);

const locales = ["en", "zh", "es", "fr", "tr", "de", "it", "ko", "pt-BR"];

test("Guide advertises ten extra Pro Credits each month", () => {
  assert.equal(
    translations["onboarding.premium-credits"].en,
    "10 extra Pro Credits each month",
  );

  for (const key of ["onboarding.premium-credits", "onboarding.plans-message"]) {
    for (const locale of locales) {
      const value = translations[key][locale];
      assert.match(value, /10/, `${key} is missing the 10-Credit allowance in ${locale}`);
      assert.doesNotMatch(value, /15/, `${key} still advertises 15 Credits in ${locale}`);
    }
  }
});

test("App Pro credit policy surfaces advertise ten extra monthly Credits", () => {
  for (const key of [
    "credits.activity.pro-renew-detail",
    "premium.pro-description",
  ]) {
    for (const locale of locales) {
      const value = translations[key][locale];
      assert.match(value, /10/, `${key} is missing the 10-Credit allowance in ${locale}`);
      assert.doesNotMatch(value, /15/, `${key} still advertises 15 Credits in ${locale}`);
    }
  }

  for (const locale of locales) {
    const value = legalTranslations["legal.terms-body"][locale];
    assert.match(value, /10/, `legal.terms-body is missing the 10-Credit allowance in ${locale}`);
    assert.doesNotMatch(value, /15/, `legal.terms-body still advertises 15 Credits in ${locale}`);
  }

  for (const group of storeKit.subscriptionGroups) {
    for (const subscription of group.subscriptions) {
      for (const localization of subscription.localizations) {
        assert.match(
          localization.description,
          /10/,
          `${subscription.productID} is missing the 10-Credit allowance in ${localization.locale}`,
        );
        assert.doesNotMatch(
          localization.description,
          /15/,
          `${subscription.productID} still advertises 15 Credits in ${localization.locale}`,
        );
      }
    }
  }
});
