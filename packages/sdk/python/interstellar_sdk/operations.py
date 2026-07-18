"""Generated from openapi/openapi.yaml; do not edit manually."""

from __future__ import annotations

from typing import Final

OPERATIONS: Final[dict[str, dict[str, str]]] = {
    "cancelJob": {
        "method": "POST",
        "path": "/api/v1/jobs/{id}/cancel"
    },
    "confirmAnalysisRecipe": {
        "method": "POST",
        "path": "/api/v1/analysis-recipes/{id}/confirm"
    },
    "createAnalysisDraft": {
        "method": "POST",
        "path": "/api/v1/analysis-drafts"
    },
    "createCalculation": {
        "method": "POST",
        "path": "/api/v1/calculations"
    },
    "createRender": {
        "method": "POST",
        "path": "/api/v1/renders"
    },
    "createReport": {
        "method": "POST",
        "path": "/api/v1/reports"
    },
    "createRulePack": {
        "method": "POST",
        "path": "/api/v1/rule-packs"
    },
    "createRulePackVersion": {
        "method": "POST",
        "path": "/api/v1/rule-packs/{id}/versions"
    },
    "createShare": {
        "method": "POST",
        "path": "/api/v1/shares"
    },
    "createSubject": {
        "method": "POST",
        "path": "/api/v1/subjects"
    },
    "createSubjectVersion": {
        "method": "POST",
        "path": "/api/v1/subjects/{id}/versions"
    },
    "deleteSubject": {
        "method": "DELETE",
        "path": "/api/v1/subjects/{id}"
    },
    "exportProjectArchive": {
        "method": "POST",
        "path": "/api/v1/exports/project-archives"
    },
    "getAnalysisDraft": {
        "method": "GET",
        "path": "/api/v1/analysis-drafts/{id}"
    },
    "getAnalysisIntentVersion": {
        "method": "GET",
        "path": "/api/v1/analysis-intents/{id}/versions/{version}"
    },
    "getAnalysisModel": {
        "method": "GET",
        "path": "/api/v1/analysis-models/{id}"
    },
    "getAnalysisModelVersion": {
        "method": "GET",
        "path": "/api/v1/analysis-models/{id}/versions/{version}"
    },
    "getAnalysisRecipe": {
        "method": "GET",
        "path": "/api/v1/analysis-recipes/{id}"
    },
    "getArtifact": {
        "method": "GET",
        "path": "/api/v1/artifacts/{id}"
    },
    "getCalculation": {
        "method": "GET",
        "path": "/api/v1/calculations/{id}"
    },
    "getCalculationTable": {
        "method": "GET",
        "path": "/api/v1/calculations/{id}/tables/{table_id}"
    },
    "getDatasetVersion": {
        "method": "GET",
        "path": "/api/v1/datasets/{id}/versions/{version}"
    },
    "getJob": {
        "method": "GET",
        "path": "/api/v1/jobs/{id}"
    },
    "getReport": {
        "method": "GET",
        "path": "/api/v1/reports/{id}"
    },
    "getReportRulePackVersion": {
        "method": "GET",
        "path": "/api/v1/report-rule-packs/{id}/versions/{version}"
    },
    "getRulePackVersion": {
        "method": "GET",
        "path": "/api/v1/rule-packs/{id}/versions/{version}"
    },
    "getSubject": {
        "method": "GET",
        "path": "/api/v1/subjects/{id}"
    },
    "getTopicModelVersion": {
        "method": "GET",
        "path": "/api/v1/topic-models/{id}/versions/{version}"
    },
    "importProjectArchive": {
        "method": "POST",
        "path": "/api/v1/imports/project-archives"
    },
    "listAnalysisIntents": {
        "method": "GET",
        "path": "/api/v1/analysis-intents"
    },
    "listAnalysisModels": {
        "method": "GET",
        "path": "/api/v1/analysis-models"
    },
    "listCalculations": {
        "method": "GET",
        "path": "/api/v1/calculations"
    },
    "listDatasetVersions": {
        "method": "GET",
        "path": "/api/v1/datasets/{id}/versions"
    },
    "listDatasets": {
        "method": "GET",
        "path": "/api/v1/datasets"
    },
    "listEntryPoints": {
        "method": "GET",
        "path": "/api/v1/entry-points"
    },
    "listReportArtifacts": {
        "method": "GET",
        "path": "/api/v1/reports/{id}/artifacts"
    },
    "listReportConclusions": {
        "method": "GET",
        "path": "/api/v1/reports/{id}/conclusions"
    },
    "listReportFindings": {
        "method": "GET",
        "path": "/api/v1/reports/{id}/findings"
    },
    "listReportProfiles": {
        "method": "GET",
        "path": "/api/v1/report-profiles"
    },
    "listSubjectVersions": {
        "method": "GET",
        "path": "/api/v1/subjects/{id}/versions"
    },
    "listSubjects": {
        "method": "GET",
        "path": "/api/v1/subjects"
    },
    "listTechniques": {
        "method": "GET",
        "path": "/api/v1/techniques"
    },
    "listTopicModels": {
        "method": "GET",
        "path": "/api/v1/topic-models"
    },
    "renderReport": {
        "method": "POST",
        "path": "/api/v1/reports/{id}/renders"
    },
    "resolveAnalysisRecipe": {
        "method": "POST",
        "path": "/api/v1/analysis-recipes/resolve"
    },
    "resolveShare": {
        "method": "GET",
        "path": "/api/v1/shares/{share_ref}"
    },
    "revokeShare": {
        "method": "DELETE",
        "path": "/api/v1/shares/{share_ref}"
    },
    "streamJobEvents": {
        "method": "GET",
        "path": "/api/v1/jobs/{id}/events"
    },
    "updateAnalysisDraft": {
        "method": "PATCH",
        "path": "/api/v1/analysis-drafts/{id}"
    },
    "validateCustomAnalysisModel": {
        "method": "POST",
        "path": "/api/v1/analysis-models/validate-custom"
    },
    "validateReportRulePack": {
        "method": "POST",
        "path": "/api/v1/report-rule-packs/validate"
    },
    "validateRulePack": {
        "method": "POST",
        "path": "/api/v1/rule-packs/validate"
    }
}
