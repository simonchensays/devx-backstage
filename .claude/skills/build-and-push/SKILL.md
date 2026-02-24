---
name: build-and-push
description: Build the Backstage Docker image and push it to ECR
disable-model-invocation: true
argument-hint: "[tag] (default: latest)"
allowed-tools: Bash(yarn *), Bash(docker *), Bash(aws *)
---

Build the Backstage Docker image and push it to ECR.

**Tag:** Use `$ARGUMENTS` if provided, otherwise `latest`.

## Steps

1. Ensure AWS SSO session is active:
```bash
aws sts get-caller-identity --profile devx-backstage
```
If credentials are expired, run `aws sso login --profile devx-backstage` and wait for the user to complete browser auth.

2. Build the backend (from `backstage/` directory):
```bash
cd backstage && yarn install --immutable && yarn tsc && yarn build:backend
```

3. Build the Docker image:
```bash
cd backstage && yarn build-image
```

4. Authenticate Docker to ECR:
```bash
aws ecr get-login-password --region us-east-1 --profile devx-backstage \
  | docker login --username AWS --password-stdin 127325447618.dkr.ecr.us-east-1.amazonaws.com
```

5. Tag and push:
```bash
docker tag backstage:latest 127325447618.dkr.ecr.us-east-1.amazonaws.com/devx-backstage:${TAG}
docker push 127325447618.dkr.ecr.us-east-1.amazonaws.com/devx-backstage:${TAG}
```
Where `${TAG}` is `$ARGUMENTS` if provided, otherwise `latest`.

6. Verify the image is in ECR:
```bash
aws ecr describe-images --repository-name devx-backstage --region us-east-1 --profile devx-backstage \
  --query "imageDetails[?contains(imageTags, '${TAG}')] | [0].{digest: imageDigest, pushed: imagePushedAt, size: imageSizeInBytes, tags: imageTags}"
```

7. Report the final image URI: `127325447618.dkr.ecr.us-east-1.amazonaws.com/devx-backstage:${TAG}`
