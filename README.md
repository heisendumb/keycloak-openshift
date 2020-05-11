Para implantação do serviço abaixo foi utilizado como base o repositório do [Keycloak](https://github.com/keycloak/keycloak-containers).

Esse documento apresenta instruções passo a passo sobre como implantar Keycloak (modo cluster) em um cluster de OpenShift. 

### Índice
<!--ts-->
 * [Imagem do Keycloak em contêiner Docker](#imagem-do-contêiner)
 * [Implantação Keycloak](#implantação-keycloak)
 * [Alterações realizadas](#alterações-realizadas)
 * [Atualização Automatizadada](#atualização-automatizada)
 * [Configuração do SSO](#configuração-do-sso)
 * [Dúvidas frequentes](#dúvidas-frequentes)
<!--te-->

## Imagem do Contêiner

Construa a imagem do contêiner Docker:

```
[username@hostname ~]$ docker build -t keycloak-local:9.0.2 -f ${ROOT_PATH}/srv/keycloak/sso/Dockerfile
````

### Rotulando Imagem

Crie o rótulo da imagem segundo o ambiente que será implantado o contêiner, neste caso de produção.

#### Intranet
```
[username@hostname ~]$ docker tag keycloak-local:9.0.2 docker-registry-default.example.io/sso/keycloak:latest 
```

---
### Empurrando Imagem ao Registry no OpenShift

Crie/atualize a imagem do Keycloak no Docker registry no OpenShift. É necessário fazer login no registry do Docker hospedado no **OpenShift**. 

O login no registry é realizado através do comando:

#### Intranet
```
[username@hostname ~]$ docker login docker-registry-default.example.io
```

A seguir está comando para criar/atualizar a imagem no registry do Docker:

#### Produção
```
[username@hostname ~]$ docker push docker-registry-default.example.io/sso/keycloak:latest 
```

---
## Implantação Keycloak

Para prosseguir nesta etapa é necessário realizar login no OpenShift através do seguinte comando:

```
[username@hostname ~]$ oc login okd.example.io
```

Isso irá implantar um cluster de Keycloak com 2 nós de execução. Todos os requisitos como os objetos do k8s namespace, services e routes serão criados.

```
[username@hostname ~]$ make all
```

Esse comando irá criar os seguintes recursos:

* 1 namespace denominado de sso no Openshift.
* 2 pods de Wildfly, que estarão sendo executados em nós diferentes da região de infraestrutura.
* 3 serviços, sendo o primeiro para service discovery nós do Wildfly, segundo para healtcheck da aplicação e o terceiro para integração com a rota que será criada.
* 2 rotas, sendo a primeira responsável pelo acesso ao realms do Keycloak para autenticação e a segunda foi criada utilizando um **white list** para reestringir o acesso de administrador no Keycloak.

### Pods

```
[username@hostname ~]$ oc get pod -n sso
NAME               READY     STATUS    RESTARTS   AGE
keycloak-8-55svj   1/1       Running   0          4d
keycloak-8-n7gnk   1/1       Running   0          4d
```

### Services

```
[username@hostname ~]$ oc get services -n sso
NAME               TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
keycloak-cluster   ClusterIP   None             <none>        80/TCP         4d
keycloak-service   NodePort    172.30.102.42    <none>        80:30392/TCP   4d
secure-keycloak    ClusterIP   172.30.238.241   <none>        8443/TCP       4d
```

### Routes

```
[username@hostname ~]$ oc get routes -n sso
NAME                    HOST/PORT                          PATH                   SERVICES          PORT       TERMINATION          WILDCARD
secure-admin-keycloak   sso.example.com ... 1 more         /auth/realms/master/   secure-keycloak   8443-tcp   reencrypt/Redirect   None
secure-keycloak         sso.example.com ... 1 more                                secure-keycloak   8443-tcp   reencrypt/Redirect   None
```

---
## Alterações realizadas

### Sincronização do Infinispan

* **Para sincronização do infinispan entre os nós do cluster de Wildfly foi necessário adicionar os seguintes comandos no default.cli**

```
/subsystem=infinispan/cache-container=keycloak/distributed-cache=sessions:remove()
/subsystem=infinispan/cache-container=keycloak/distributed-cache=authenticationSessions:remove()
/subsystem=infinispan/cache-container=keycloak/distributed-cache=offlineSessions:remove()
/subsystem=infinispan/cache-container=keycloak/distributed-cache=clientSessions:remove()
/subsystem=infinispan/cache-container=keycloak/distributed-cache=offlineClientSessions:remove()
/subsystem=infinispan/cache-container=keycloak/distributed-cache=loginFailures:remove()

/subsystem=infinispan/cache-container=keycloak/replicated-cache=sessions:add()
/subsystem=infinispan/cache-container=keycloak/replicated-cache=authenticationSessions:add()
/subsystem=infinispan/cache-container=keycloak/replicated-cache=offlineSessions:add()
/subsystem=infinispan/cache-container=keycloak/replicated-cache=clientSessions:add()
/subsystem=infinispan/cache-container=keycloak/replicated-cache=offlineClientSessions:add()
/subsystem=infinispan/cache-container=keycloak/replicated-cache=loginFailures:add()
```

## Armazenamento de credenciais para BD


* **Criação do objeto Secret do k8s para armazenamento das credenciais**

No caso das credenciais da base de dados, é possível serem codificadas em base64.

```
---
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-admin-user-secret
  namespace: sso
  labels:
    application: keycloak
data:
  username: "username"
---
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-admin-password-secret
  namespace: sso
  labels:
    application: keycloak
data:
  password: "password"
---
apiVersion: v1
kind: Secret
metadata:
  name: databse-password-secret
  namespace: sso
  labels:
    application: keycloak
stringData:
  password: "password"
---
apiVersion: v1
kind: Secret
metadata:
  name: database-username-secret
  namespace: sso
  labels:
    application: keycloak
stringData:
  username: "username"
```

* **Configuração do objeto AutoScale do k8s para autoescalonamento dos containers**

```
--- 
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  name: keycloak-scaling
  namespace: sso
spec:
  scaleTargetRef:
    kind: DeploymentConfig 
    name: keycloak 
    apiVersion: apps/v1 
    subresource: scale
  minReplicas: 1 
  maxReplicas: 2
  targetCPUUtilizationPercentage: 90
---
```

---
## Dúvidas frequentes

* **A atualização somente do arquivo de README.md irá disparar o pipeline, para que isso não ocorra é necessário adicionar [ci skip] na mensagem de commit quando empurrar a atualização ao repositório**.

```
[username@hostname ~]$ git commit -m 'Updated README.md... [ci skip]'
```

* **Não é possível implantar o cluster de Keycloak quando já existe uma instalação atual e também não é possível atualizar (rollout) de forma manual utilizando o Makefile.**

```
[username@hostname ~]$ make all
oc create -f keycloak-https-mutual-tls.yml
route "secure-keycloak-cloudint" created
Error from server (AlreadyExists): error when creating "keycloak-https-mutual-tls.yml": services "keycloak-service" already exists
Error from server (AlreadyExists): error when creating "keycloak-https-mutual-tls.yml": services "keycloak-cluster" already exists
Error from server (AlreadyExists): error when creating "keycloak-https-mutual-tls.yml": services "secure-keycloak" already exists
Error from server (AlreadyExists): error when creating "keycloak-https-mutual-tls.yml": routes "secure-admin-keycloak" already exists
Error from server (AlreadyExists): error when creating "keycloak-https-mutual-tls.yml": routes "secure-keycloak" already exists
Error from server (AlreadyExists): error when creating "keycloak-https-mutual-tls.yml": deploymentconfigs "keycloak" already exists
Error from server (AlreadyExists): error when creating "keycloak-https-mutual-tls.yml": secrets "postgresql-password-secret" already exists
Error from server (AlreadyExists): error when creating "keycloak-https-mutual-tls.yml": secrets "postgresql-username-secret" already exists
Error from server (AlreadyExists): error when creating "keycloak-https-mutual-tls.yml": secrets "keycloak-admin-user-secret" already exists
Error from server (AlreadyExists): error when creating "keycloak-https-mutual-tls.yml": secrets "keycloak-admin-password-secret" already exists
Error from server (AlreadyExists): error when creating "keycloak-https-mutual-tls.yml": horizontalpodautoscalers.autoscaling "keycloak-scaling" already exists
```

Para resolução do problema é necessário excluir o **deploymentconfig** atual e recriar o cluster de Keycloak através do seguinte comando:

```
$ make recreate
```

* **Na inicialização cluster não ocorreu sincronização entre os nós do cluster.**

Log de output de um dos nós do cluster:

```
15:40:13,331 INFO  [org.wildfly.extension.undertow] (MSC service thread 1-4) WFLYUT0006: Undertow HTTPS listener https listening on 0.0.0.0:8443
15:40:14,186 INFO  [org.infinispan.factories.GlobalComponentRegistry] (MSC service thread 1-3) ISPN000128: Infinispan version: Infinispan 'Infinity Minus ONE +2' 9.4.14.Final
15:40:14,494 INFO  [org.infinispan.remoting.transport.jgroups.JGroupsTransport] (MSC service thread 1-2) ISPN000078: Starting JGroups channel ejb
15:40:14,494 INFO  [org.infinispan.remoting.transport.jgroups.JGroupsTransport] (MSC service thread 1-4) ISPN000078: Starting JGroups channel ejb
15:40:14,497 INFO  [org.infinispan.remoting.transport.jgroups.JGroupsTransport] (MSC service thread 1-1) ISPN000078: Starting JGroups channel ejb
15:40:14,497 INFO  [org.infinispan.remoting.transport.jgroups.JGroupsTransport] (MSC service thread 1-3) ISPN000078: Starting JGroups channel ejb
15:40:14,506 INFO  [org.infinispan.CLUSTER] (MSC service thread 1-1) ISPN000094: Received new cluster view for channel ejb: [keycloak-8-55svj|9] (1) [keycloak-8-55svj]
```

É necessário remover um dos pods do cluster para ressincronização entre os nós do cluster, a seguir há um passo a passo para resolução do problema.

1. Listar os pods atuais em execução do Keycloak.

```
[username@hostname ~]$ oc get pod -n sso
NAME               READY     STATUS    RESTARTS   AGE
keycloak-8-55svj   1/1       Running   0          4d
keycloak-8-n7gnk   1/1       Running   0          4d
```

2. Escolha um dos pods em execução e remova.

```
[username@hostname ~]$ oc delete pod keycloak-8-55svj -n sso
pod "keycloak-8-55svj" deleted
```

3. Em seguida analise o log do Wildfly do pod/container que foi recriado procurando algo semelhante com a seguinte mensagem:

```
19:56:26,098 INFO  [org.wildfly.extension.undertow] (MSC service thread 1-2) WFLYUT0006: Undertow HTTPS listener https listening on 0.0.0.0:8443
19:56:26,278 WARN  [org.jboss.as.dependency.private] (MSC service thread 1-2) WFLYSRV0018: Deployment "deployment.keycloak-server.war" is using a private module ("org.kie") which may be changed or removed in future versions without notice.
19:56:27,852 INFO  [org.infinispan.factories.GlobalComponentRegistry] (MSC service thread 1-3) ISPN000128: Infinispan version: Infinispan 'Infinity Minus ONE +2' 9.4.14.Final
19:56:28,107 INFO  [org.infinispan.remoting.transport.jgroups.JGroupsTransport] (MSC service thread 1-1) ISPN000078: Starting JGroups channel ejb
19:56:28,110 INFO  [org.infinispan.remoting.transport.jgroups.JGroupsTransport] (MSC service thread 1-4) ISPN000078: Starting JGroups channel ejb
19:56:28,110 INFO  [org.infinispan.remoting.transport.jgroups.JGroupsTransport] (MSC service thread 1-2) ISPN000078: Starting JGroups channel ejb
19:56:28,111 INFO  [org.infinispan.remoting.transport.jgroups.JGroupsTransport] (MSC service thread 1-3) ISPN000078: Starting JGroups channel ejb
19:56:28,152 INFO  [org.infinispan.CLUSTER] (MSC service thread 1-1) ISPN000094: Received new cluster view for channel ejb: [keycloak-8-55svj|9] (2) [keycloak-8-55svj, keycloak-8-n7gnk]
```

* **Não é possível desescalar o cluster para 0 réplica utilizando o console (cockpit) no OpenShift.**

Como foi implementado o autoscale de forma horizontal no cluster, utilizando o console não é possível desescalar o cluster para 0 réplica. Para realizar essa ação é necessário utilzar a **API** ou **CLI** do OpenShift.

Para tornar mais simples essa ação, será demonstrado como desescalar o cluster utilizando **CLI** através do exemplo à seguir:

```
oc scale dc/keycloak --replicas=0 -n sso
```
