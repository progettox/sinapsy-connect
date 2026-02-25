# Docs Index

## Start here
1. `docs/01_VISION.md`
2. `docs/02_SCOPE_MVP.md`
3. `docs/product/PRD.md`
4. `docs/flows/STATE_MACHINES.md`
5. `docs/data/DATA_MODEL.md`
6. `docs/ui/SCREEN_INVENTORY.md`
7. `docs/engineering/FOLDER_STRUCTURE_FLUTTER.md`
8. `prompts/CODEX_SYSTEM_PROMPT.md`

## Source of truth rules
- Se c’è conflitto: vince **Scope MVP** → poi **State Machines** → poi **Data Model**.
- L’LLM non deve inventare feature fuori scope.

## Roles
- Brand
- Creator (influencer)
- Service Provider (fotografo/videomaker)

Nel codice MVP puoi unificare Creator + Service Provider come `role = creator` e usare `category` per distinguere.