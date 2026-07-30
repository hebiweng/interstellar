# iOS interpretation content workflow

The application runtime reads only compiled `PrivateCorpus-<locale>.json` packs.
It never reads Obsidian, Markdown, TypeScript corpus files, or translation
spreadsheets.

Tracked files contain only the public engine, schema, card IDs, validation, and
rendering code. Original interpretation text and selection/composition rules
stay in ignored paths:

```text
ios/PrivateContent/Corpus-zh-Hans.json
ios/PrivateContent/Corpus-en.json
ios/PrivateRules/Composition-zh-Hans.json
ios/PrivateRules/Composition-en.json
ios/App/Resources/PrivateCorpus-zh-Hans.json
ios/App/Resources/PrivateCorpus-en.json
ios/TranslationExports/
```

Build a runtime pack:

```sh
node scripts/build-ios-content-pack.mjs \
  --locale zh-Hans \
  --version ios-v1-YYYY-MM-DD
```

Export untranslated English rows by stable corpus ID:

```sh
node scripts/build-ios-content-pack.mjs \
  --locale en \
  --version ios-v1-YYYY-MM-DD \
  --include-sample \
  --export-missing
```

The build fails when IDs are duplicated, locale boundaries are crossed, one of
the 28 card rules is missing, a required template binding is absent, an
unapproved entry reaches the runtime pack, or English and Chinese IDs drift.
`--include-sample` is for a Debug prototype only. Release loading accepts
`approved` entries exclusively.
