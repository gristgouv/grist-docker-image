# Image de conteneur pour Grist.gouv

## Créer une nouvelle version

### Pour une nouvelle version de Grist

Instructions à suivre lorsque GristLabs publie une nouvelle version de Grist :
- Lancer [l'action **Update GRIST_VERSION**](https://github.com/gristgouv/grist-docker-image/actions/workflows/autoupdate-grist.yml)
- Merger la PR créée par l'action
- Sur la branche `main`, créer un nouveau tag avec le format `x.x.x-1` où `x.x.x` est le numéro de version chez GristLabs sans le préfixe `v`.

### Pour des modifications au Dockerfile

Si nous avons besoin de recréer une version distincte de l'image de conteneur pour une même version de Grist, nous incrémentons le numéro d'itération.
Par exemple, si le dernier tag est `1.6.1-2`, alors il faut créer sur la branche `main` le tag `1.6.1-3`.
