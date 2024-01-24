Any Kubernetes YAML files you add or change in this folder
will be automatically applied to the staging cluster when
the change is committed and pushed to the "master" branch.

The configuration for this can be found here: https://github.com/qdrant/qdrant-cloud/tree/main/environments/staging/apps/haloperidol

To see the rendered manifests, run this from inside this folder:

`kustomize build . | less`
