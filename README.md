# springboot-postgres-demo Application


# Table of Contents
1. [Overview](#Overview)
2. [Design](#Design)
3. [Building](#Building)
4. [Deploying](#Deploying)
5. [CI](#CI)
6. [CD](#CD)


## Overview
This is a UI application with a Database backend.  The application is based on the [Spring Boot Petclinic](https://github.com/spring-projects/spring-petclinic) application.  The original application utilized H2 and MySQL for persistence.  This version swaps out MySQL for PostgreSQL.

As such, it is composed of 2 deployments:
- The UI application
- PostgreSQL backend database

The application uses Spring JPA for ORM.  When bootstrapping, it initializes the database using [DDL and DML scripts](https://github.com/abryson-redhat/springboot-postgres-demo/tree/main/src/main/resources/db/postgresql).

For the UI application, it uses Maven for Java builds and has a Containerfile that constructs an image using the OpenJDK 17 builder image.

It implements a PetClinic UI accessible via the browser.

A request was made for a Secrets implementation that leveraged GitHub environment secrets.  This project has a number of dependencies that require secrets.  So, the secrets workflow was implemented for this project.  

That workflow can be found [here](https://github.com/abryson-redhat/springboot-postgres-demo/blob/main/.github/workflows/installSecret.yml).


## Design
GitHub workflows are used for CI and CD to the DEV environment.  The `ci.yml` workflow is triggered on push events to the repository.


The application uses an initContainer to execute psql against a couple of DDL scripts.  They set the stage for the JPA bootstrap which executes DML scripts to initialize the PostgreSQL database.

> **initContainer** for initializing the database
```yaml
      initContainers:
        - name: psql-client-container
          image: nexus-registry-nexus.apps.cluster-vkngf.dynamic.redhatworkshops.io/repository/smbc-demo/psql-client:latest
  ...
          command: ['bash', '-c', 'psql < /temp/user.sql && psql -d petclinic < /temp/schema_drop.sql']
```



> **CI tree**\
.github/\
└── workflows\
    ├── ci.yml\
    ├── contextToEnvVars.yml\
    ├── installSecret.yml\
    └── sayhello.yml



#### Installing secrets
You can use the installSecrets.yml workflow script to install individual secrets.  Secret data must be in OpenShift template format with parameters defined.  

> :warning: The template **MUST be base64 encoded** and pasted into the GitHub environment secret.

<br/>

##### Steps to save secret and install it:

<br/>

- copy manifest to clipboard with base64 encoding
> **Example registry secret template copy**
```bash
    cat redhat-registry.yaml | base64 -i -w 0 | xclip -selection clipboard
```

- Paste the encoded template data into the GitHub environment secret.
- Navigate to: Actions / Install Secret
- Enter the GitHub secret key (name) into the prompt.  
- Click "Run workflow".

## Building
#### With tests
```bash
  mvn clean package 
```
#### Without tests
```bash
  mvn -DskipTests=true clean package
```

### Testing

#### Unit tests
The application has a single unit test.  The execute the test locally...
```bash
  mvn test
```

#### Starting the application locally
```bash
  mvn -DskipTests=true spring-boot:run
```

This will bootstrap the application which can be accessed via the browser using *port 8080*.

## Deploying
This project uses Kustomize for deploying artifacts.  The Kustomize manifests are located in [a separate manifest repository](https://github.com/abryson-redhat/argocd-demo/tree/kustomize/gitops/manifests/busunit1/integration/teams/appteam1/apps/springboot-postgres-demo).

To trigger a deployment, the `ci.yml` workflow executes a **deploytodev** job that updates a `app-deployment.yaml` with an updated image pull spec for the application and psql-client images.

This will cause ArgoCD to update the OpenShift deployment with a sync operation.

> **Application** and **Database** manifests
```bash
overlays/dev
├── app-deployment.yaml
├── app-route.yaml
├── app-service.yaml
├── db-deployment.yaml
├── db-pvc.yaml
├── db-service.yaml
└── kustomization.yaml
```



##  CI
CI is implemented via a [GitHub Workflow](https://docs.github.com/en/actions/using-workflows).
The CI workflow is defined [here](https://github.com/abryson-redhat/springboot-postgres-demo/.github/workflows/ci.yml).

It has 6 jobs:
- **javabuild**:      builds the java archive and executes unit tests.
- **sonarqube**:      executes sonarqube code analysis by connecting to a remote sonarqube instance.
- **dockerimagebuild**:   uses the buildah runner image to execute a buildah image build using the Containerfile on the psql-client image.
- **s2iimagebuild**: uses S2I to build the application image.  it accomplishes this by creating a temporary BuildConfig resource.
- **imagescan**:      executes an ACS image scan, on the application image, using the image-scan runner image.
- **deploytodev**:    deploys the project via an update to the `app-deployment.yaml` file for the DEV instance.  it updates both the application and psql-client image pull specs.


## CD
CD is implemented via ArgoCD and Kustomize.  The project has Kustomize manifests hosted in a separate manifest repository.  The last job in the CI flow updates the `app-deployment.yaml` file with the new image pull specs for the application and psql-client images.  This will trigger an ArgoCD sync operation.

#### CD sequencing
![CD sequencing](https://github.com/abryson-redhat/springboot-postgres-demo/blob/main/images/CD_sequence_diagram-Kustomize.png)

