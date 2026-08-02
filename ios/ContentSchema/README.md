# iOS interpretation content workflow (Copy Catalog v2)

The runtime reads compiled `CopyCatalog-<locale>.json` packs (schemaVersion 2). It never reads Obsidian, Markdown, TypeScript corpus files, or translation spreadsheets directly.

## Supported locales

- `en`
- `zh-Hans`
- `es`
- `fr`

## Source files (private, not tracked)

```text
ios/PrivateContent/copy-catalog-v2/Interstellar_Copy_Catalog_<locale>_v2_three-layers.json
ios/PrivateContent/week/Content-<locale>.json        # legacy, not migrated yet
ios/PrivateContent/Corpus-<locale>.json              # legacy, not migrated yet (Ask)
ios/App/Resources/PrivateCorpus-<locale>.json          # legacy, not migrated yet (Ask)
ios/App/Resources/CopyCatalog-<locale>.json            # v2 runtime pack
ios/PrivateRules/Composition-<locale>.json            # legacy Ask rules
ios/TranslationExports/
```

## Build the runtime packs

```sh
npm run ios:copy:build
```

This regenerates `ios/App/Resources/CopyCatalog-{en,zh-Hans,es,fr}.json` from the v2 source files.

## Validate

```sh
npm run ios:copy:validate
```

The build fails when:

- a source catalog is not `approved` (unless `--trust-approved` is passed),
- `shared`, `modern`, or `classical` roots are missing,
- one of the 51 card contracts is missing or has an unknown card ID,
- a contract lacks `evidenceByPreset` or `copySourceByPreset` for a preset,
- consumer copy declares more than two variables, or technical copy declares more than three,
- a template variable is undeclared or malformed,
- a copy source path is duplicated,
- `themeRulesByPreset` is missing for `modern` or `classical`.

## Legacy Ask and Week content

Ask and Week still use the legacy `PrivateContent/...` and `PrivateCorpus-*.json` workflow. They are intentionally not migrated in this pass because the new zip does not contain Week content.
