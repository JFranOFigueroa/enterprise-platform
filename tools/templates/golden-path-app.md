# Golden Path for New Applications

## Steps

1. Create repository in `applications/`
2. Create Helm chart with standard structure
3. Add ArgoCD Application in `bootstrap/gitops/applications/`
4. Add values per environment
5. `git push`
6. ArgoCD deploys automatically

## The developer never touches kubectl.
