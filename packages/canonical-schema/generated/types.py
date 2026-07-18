"""AUTO-GENERATED stable contract index types. DO NOT EDIT.

Payload validation remains the responsibility of the source JSON Schemas.
"""

from __future__ import annotations

from typing import Final, Literal, TypeAlias, TypedDict

JSONPrimitive: TypeAlias = None | bool | int | float | str
JSONValue: TypeAlias = JSONPrimitive | list["JSONValue"] | dict[str, "JSONValue"]
JSONObject: TypeAlias = dict[str, JSONValue]

class ContractDescriptor(TypedDict):
    schema_id: str
    title: str
    definitions: tuple[str, ...]
    sha256: str

CANONICAL_CONTRACTS: Final[dict[str, ContractDescriptor]] = {
    'analysis-draft.schema.json': {
        'schema_id': 'https://interstellar.dev/schemas/v1/analysis-draft.schema.json',
        'title': 'AnalysisDraft',
        'definitions': (),
        'sha256': 'baaf75d9f90502ba6e25b8d1512f9def1df690513a9d57a522067ac2876a9ac4',
    },
    'analysis-recipe.schema.json': {
        'schema_id': 'https://interstellar.dev/schemas/v1/analysis-recipe.schema.json',
        'title': 'AnalysisRecipe',
        'definitions': ('RecipeNode', 'RecipeOutputs', 'ReusePlan'),
        'sha256': '2e03b04ae20d2eb9883a7f1c4007c96a55cf1aefcf73ff79e5ea88629ec40174',
    },
    'calculation-snapshot.schema.json': {
        'schema_id': 'https://interstellar.dev/schemas/v1/calculation-snapshot.schema.json',
        'title': 'CalculationSnapshot',
        'definitions': ('AnalysisModelExecution', 'CalculationResult', 'RecipeExecutionRequest'),
        'sha256': '047e99ca08a1f3aed361fe10e9a798b457523289aa042f1ae329d4c561179592',
    },
    'chart-request.schema.json': {
        'schema_id': 'https://interstellar.dev/schemas/v1/chart-request.schema.json',
        'title': 'ChartRequest',
        'definitions': ('ChartDefinition', 'ChartSettings', 'SubjectInput'),
        'sha256': '8c5f2713f7a8810f85943f83b7e91982f829324dc709cddbcd706a01289aa17f',
    },
    'chart-result.schema.json': {
        'schema_id': 'https://interstellar.dev/schemas/v1/chart-result.schema.json',
        'title': 'ChartResult',
        'definitions': ('Aspect', 'AstronomicalContext', 'CelestialPosition', 'Chart', 'House', 'HouseSet', 'Point', 'Provenance'),
        'sha256': '11433428240824149d1cf9547b637c2a233df362eeb99ce824f46a936d62cfbe',
    },
    'common.schema.json': {
        'schema_id': 'https://interstellar.dev/schemas/v1/common.schema.json',
        'title': 'Interstellar Common Types',
        'definitions': ('ChartFamily', 'ContentHash', 'DatasetReference', 'EngineReference', 'EvidencePolarity', 'Identifier', 'JobStatus', 'Maturity', 'PageInfo', 'ResourceStatus', 'ScoreSet', 'SemVer', 'SourceReference', 'SubjectKind', 'TimeWindow', 'VersionReference', 'Warning'),
        'sha256': '298a7e4c563a68563ffb8fd8f655f78f45734809c825b3051369dd5580b29138',
    },
    'evidence.schema.json': {
        'schema_id': 'https://interstellar.dev/schemas/v1/evidence.schema.json',
        'title': 'Evidence',
        'definitions': (),
        'sha256': 'b15b785197c19993d8d0393921a99ad2380f4ad2868f129d79d9e705506a00c4',
    },
    'job.schema.json': {
        'schema_id': 'https://interstellar.dev/schemas/v1/job.schema.json',
        'title': 'Job',
        'definitions': (),
        'sha256': 'c4c357a97487c89ee5c1cf409f0d858f19f20e2460bdc536b212d325f7dfa315',
    },
    'location.schema.json': {
        'schema_id': 'https://interstellar.dev/schemas/v1/location.schema.json',
        'title': 'Location',
        'definitions': (),
        'sha256': '9cf195b02fb7bb6c8498d77fafd0b00bf15b69c0193b0b3cc766d92d1366d42c',
    },
    'output-manifest.schema.json': {
        'schema_id': 'https://interstellar.dev/schemas/v1/output-manifest.schema.json',
        'title': 'OutputManifest',
        'definitions': (),
        'sha256': '5633482ba2e7e25dc2844b704af971cde356b9ba1cdf64aa596eb65df5a04d79',
    },
    'problem-error.schema.json': {
        'schema_id': 'https://interstellar.dev/schemas/v1/problem-error.schema.json',
        'title': 'ProblemError',
        'definitions': (),
        'sha256': '23047cc1f852a70b46c71040799b9b3e4f56366303cecdc24237d7e357d03323',
    },
    'render-spec.schema.json': {
        'schema_id': 'https://interstellar.dev/schemas/v1/render-spec.schema.json',
        'title': 'RenderSpec',
        'definitions': (),
        'sha256': 'b9ace1e122966b53af806b57affcdd1ba11e6a7846bc71e16d627c9957e9e8c6',
    },
    'report-document.schema.json': {
        'schema_id': 'https://interstellar.dev/schemas/v1/report-document.schema.json',
        'title': 'ReportDocument',
        'definitions': ('Conclusion', 'DateOrDateTime', 'Finding', 'RawFactReference', 'ReportBlock', 'ReportSection', 'ReportTimeWindow', 'TechnicalAppendix'),
        'sha256': 'e866fa556406e3e3bfdeabeb9b770632575c56cae1d2084e6d50db50abab44c8',
    },
    'subject.schema.json': {
        'schema_id': 'https://interstellar.dev/schemas/v1/subject.schema.json',
        'title': 'Subject Contracts',
        'definitions': ('Subject', 'SubjectVersion', 'SubjectVersionInput'),
        'sha256': '971efb3d1e36f5bdde09f0b584294d14c4696684bade849464f3e1f2cf0ca3ef',
    },
    'time-spec.schema.json': {
        'schema_id': 'https://interstellar.dev/schemas/v1/time-spec.schema.json',
        'title': 'TimeSpec',
        'definitions': (),
        'sha256': 'ecdcfd94323608820c8c9e587ba8597e1377e1aaecde448fc767003d7c337cbb',
    },
}

AnalysisDraftDocument: TypeAlias = JSONObject
AnalysisRecipeDocument: TypeAlias = JSONObject
AnalysisRecipeRecipeNode: TypeAlias = JSONObject
AnalysisRecipeRecipeOutputs: TypeAlias = JSONObject
AnalysisRecipeReusePlan: TypeAlias = JSONObject
CalculationSnapshotDocument: TypeAlias = JSONObject
CalculationSnapshotAnalysisModelExecution: TypeAlias = JSONObject
CalculationSnapshotCalculationResult: TypeAlias = JSONObject
CalculationSnapshotRecipeExecutionRequest: TypeAlias = JSONObject
ChartRequestDocument: TypeAlias = JSONObject
ChartRequestChartDefinition: TypeAlias = JSONObject
ChartRequestChartSettings: TypeAlias = JSONObject
ChartRequestSubjectInput: TypeAlias = JSONObject
ChartResultDocument: TypeAlias = JSONObject
ChartResultAspect: TypeAlias = JSONObject
ChartResultAstronomicalContext: TypeAlias = JSONObject
ChartResultCelestialPosition: TypeAlias = JSONObject
ChartResultChart: TypeAlias = JSONObject
ChartResultHouse: TypeAlias = JSONObject
ChartResultHouseSet: TypeAlias = JSONObject
ChartResultPoint: TypeAlias = JSONObject
ChartResultProvenance: TypeAlias = JSONObject
CommonDocument: TypeAlias = JSONObject
CommonChartFamily: TypeAlias = JSONObject
CommonContentHash: TypeAlias = JSONObject
CommonDatasetReference: TypeAlias = JSONObject
CommonEngineReference: TypeAlias = JSONObject
CommonEvidencePolarity: TypeAlias = JSONObject
CommonIdentifier: TypeAlias = JSONObject
CommonJobStatus: TypeAlias = JSONObject
CommonMaturity: TypeAlias = JSONObject
CommonPageInfo: TypeAlias = JSONObject
CommonResourceStatus: TypeAlias = JSONObject
CommonScoreSet: TypeAlias = JSONObject
CommonSemVer: TypeAlias = JSONObject
CommonSourceReference: TypeAlias = JSONObject
CommonSubjectKind: TypeAlias = JSONObject
CommonTimeWindow: TypeAlias = JSONObject
CommonVersionReference: TypeAlias = JSONObject
CommonWarning: TypeAlias = JSONObject
EvidenceDocument: TypeAlias = JSONObject
JobDocument: TypeAlias = JSONObject
LocationDocument: TypeAlias = JSONObject
OutputManifestDocument: TypeAlias = JSONObject
ProblemErrorDocument: TypeAlias = JSONObject
RenderSpecDocument: TypeAlias = JSONObject
ReportDocumentDocument: TypeAlias = JSONObject
ReportDocumentConclusion: TypeAlias = JSONObject
ReportDocumentDateOrDateTime: TypeAlias = JSONObject
ReportDocumentFinding: TypeAlias = JSONObject
ReportDocumentRawFactReference: TypeAlias = JSONObject
ReportDocumentReportBlock: TypeAlias = JSONObject
ReportDocumentReportSection: TypeAlias = JSONObject
ReportDocumentReportTimeWindow: TypeAlias = JSONObject
ReportDocumentTechnicalAppendix: TypeAlias = JSONObject
SubjectDocument: TypeAlias = JSONObject
SubjectSubject: TypeAlias = JSONObject
SubjectSubjectVersion: TypeAlias = JSONObject
SubjectSubjectVersionInput: TypeAlias = JSONObject
TimeSpecDocument: TypeAlias = JSONObject

ApiOperationId: TypeAlias = Literal['cancelJob', 'confirmAnalysisRecipe', 'createAnalysisDraft', 'createCalculation', 'createRender', 'createReport', 'createRulePack', 'createRulePackVersion', 'createShare', 'createSubject', 'createSubjectVersion', 'deleteSubject', 'exportProjectArchive', 'getAnalysisDraft', 'getAnalysisIntentVersion', 'getAnalysisModel', 'getAnalysisModelVersion', 'getAnalysisRecipe', 'getArtifact', 'getCalculation', 'getDatasetVersion', 'getJob', 'getReport', 'getReportRulePackVersion', 'getRulePackVersion', 'getSubject', 'getTopicModelVersion', 'importProjectArchive', 'listAnalysisIntents', 'listAnalysisModels', 'listCalculations', 'listDatasetVersions', 'listDatasets', 'listEntryPoints', 'listReportArtifacts', 'listReportConclusions', 'listReportFindings', 'listReportProfiles', 'listSubjectVersions', 'listSubjects', 'listTechniques', 'listTopicModels', 'renderReport', 'resolveAnalysisRecipe', 'resolveShare', 'revokeShare', 'streamJobEvents', 'updateAnalysisDraft', 'validateCustomAnalysisModel', 'validateReportRulePack', 'validateRulePack']
API_OPERATION_IDS: Final[tuple[ApiOperationId, ...]] = (
    'cancelJob',
    'confirmAnalysisRecipe',
    'createAnalysisDraft',
    'createCalculation',
    'createRender',
    'createReport',
    'createRulePack',
    'createRulePackVersion',
    'createShare',
    'createSubject',
    'createSubjectVersion',
    'deleteSubject',
    'exportProjectArchive',
    'getAnalysisDraft',
    'getAnalysisIntentVersion',
    'getAnalysisModel',
    'getAnalysisModelVersion',
    'getAnalysisRecipe',
    'getArtifact',
    'getCalculation',
    'getDatasetVersion',
    'getJob',
    'getReport',
    'getReportRulePackVersion',
    'getRulePackVersion',
    'getSubject',
    'getTopicModelVersion',
    'importProjectArchive',
    'listAnalysisIntents',
    'listAnalysisModels',
    'listCalculations',
    'listDatasetVersions',
    'listDatasets',
    'listEntryPoints',
    'listReportArtifacts',
    'listReportConclusions',
    'listReportFindings',
    'listReportProfiles',
    'listSubjectVersions',
    'listSubjects',
    'listTechniques',
    'listTopicModels',
    'renderReport',
    'resolveAnalysisRecipe',
    'resolveShare',
    'revokeShare',
    'streamJobEvents',
    'updateAnalysisDraft',
    'validateCustomAnalysisModel',
    'validateReportRulePack',
    'validateRulePack',
)
