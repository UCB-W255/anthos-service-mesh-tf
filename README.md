# Istio Playground Lab

## Overview
This lab deploys a sample app on GKE with Istio (ASM). Open your CloudShell on [Google Cloud](https://console.cloud.google.com) to run all these commands.

## Create a GKE cluster and install ASM

1.  Create a private standard zonal GKE cluster

    a. Prepare the files.

    ```bash
    export ZONE="us-central1-c"
    export PROJECT_ID=$(echo $DEVSHELL_PROJECT_ID)
    export CLUSTER_NAME="w255"
    export IP_ADDRESS=$(dig +short myip.opendns.com @resolver1.opendns.com)

    git clone https://github.com/UCB-W255/anthos-service-mesh-tf.git

    cd anthos-service-mesh-tf

    echo "project_id = ${PROJECT_ID}" >> tf-vars.tfvars
    echo "cloudshell_ip = ${IP_ADDRESS}" >> tf-vars.tfvars
    ```

    b. Download the Google Terraform Provider.

    ```bash
    terraform init
    ```
    c. Make a plan.

    ```bash
    terraform plan -var-file tf-vars.tfvars
    ```

    d. Apply the plan (it takes about 6 mins to create the infrastructure).

    *NOTE: This will incur charges/use credits.*

    ```bash
    terraform apply -var-file tf-vars.tfvars -auto-approve
    ```

2.  Connect to the cluster

    ```shell
    $ gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${ZONE}
    ```

3.  Install Anthos Service Mesh

    ```bash
    curl -sS https://storage.googleapis.com/csm-artifacts/asm/install_asm_1.9 > install_asm
    chmod +x install_asm
    ./install_asm \
    --project_id ${PROJECT_ID} \
    --cluster_name ${CLUSTER_NAME} \
    --cluster_location ${ZONE} \
    --mode install \
    --enable_all \
    --enable-registration
    ```

    Note: For ASM 1.11 version and above, `asmcli` is the preferred command.
    Public docs for the
    [latest version](https://cloud.google.com/service-mesh/docs/unified-install/install)
    of ASM detail use of `asmcli`.

    Note: install_asm script can only be executed from x86_64 architecture based
    systems.

    4.1. (optional) In newer version, we can **validate** the installation
    parameters and verify that the cluster have all what is needed.

    ```bash
    curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_1.18 > asmcli
    chmod +x asmcli
    sudo ./asmcli validate \
    --project_id ${PROJECT_ID} \
    --cluster_name ${CLUSTER_NAME} \
    --cluster_location ${ZONE} \
    --fleet_id ${PROJECT_ID} \
    --output_dir ${PROJECT_ID}
    ```

    4.2. Then to Install Anthos Service Mesh with the **enable_all** flag.

    ```bash
    curl https://storage.googleapis.com/csm-artifacts/asm/asmcli_1.18 > asmcli
    chmod +x asmcli
    ./asmcli install \
    --project_id ${PROJECT_ID} \
    --cluster_name ${CLUSTER_NAME} \
    --cluster_location ${ZONE} \
    --fleet_id ${PROJECT_ID} \
    --option legacy-default-ingressgateway \
    --enable_all \
    --ca mesh_ca
    ```

    Note: The flag **enable_all** allows the script to: Grant required IAM
    permissions, Enable the required Google APIs, Set a label on the cluster
    that identifies the mesh, Register the cluster to the fleet if it isn't
    already registered. More info:
    [Install default features and Mesh CA](https://cloud.google.com/service-mesh/docs/unified-install/install-anthos-service-mesh)

4.  Check the Istio control plane deployment

    ```shell
    $ kubectl get svc,pods -n istio-system
    ```

    Expected output:

    ``` {.no-copy}
    NAME                           TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)                                                                      AGE
    service/istio-ingressgateway   LoadBalancer   10.64.9.206    34.116.202.65   15021:31693/TCP,80:32765/TCP,443:30748/TCP,15012:30732/TCP,15443:31792/TCP   30m
    service/istiod                 ClusterIP      10.64.13.172   <none>          15010/TCP,15012/TCP,443/TCP,15014/TCP                                        31m
    service/istiod-asm-193-2       ClusterIP      10.64.3.121    <none>          15010/TCP,15012/TCP,443/TCP,15014/TCP                                        31m

    NAME READY STATUS RESTARTS AGE
    pod/istio-ingressgateway-55c757dc94-jlzg6 1/1 Running 0 30m
    pod/istio-ingressgateway-55c757dc94-vtmf2 1/1 Running 0 30m
    pod/istiod-asm-193-2-664ccd5d95-9kznq 1/1 Running 0 31m
    pod/istiod-asm-193-2-664ccd5d95-w4fgd 1/1 Running 0 31m
    ```

    Note: the `istio-ingressgateway` service is exposed via a NLB by default.
    Notice the `istio-ingressgateway` service is of type `LoadBalancer`.

    ```shell
    $ istioctl version
    ```

    NOTE: The`install_asm` shell script dowloads and makes available the
    `istioctl` binary. By default `istioctl` will connect to the cluster, using
    the default `.kubeconfig` file which was setup with the get-credentials
    command we issued earlier.

### Get an overview of your mesh

> Reference:
> [Istio: Diagnostic Tools](https://istio.io/docs/ops/troubleshooting/proxy-cmd/#get-an-overview-of-your-mesh)
>
> Important concepts:
> [Envoy Terminology](https://www.envoyproxy.io/docs/envoy/latest/intro/arch_overview/intro/terminology)
>
> Discovery Services: go/wtfds

```shell {highlight="content:proxy-status"}
$ istioctl proxy-status
```

During the installation of the Istio control plane pods, the output will be
empty:

```none {.no-copy}
$ istioctl proxy-status
NAME CDS LDS EDS RDS PILOT VERSION
```

After installation is completed, you will see the _ingressgateway_ listed:

```none {.no-copy}
$ istioctl ps # note the shortcut :)
NAME                                                   CDS        LDS        EDS        RDS          ISTIOD                                VERSION
istio-ingressgateway-55c757dc94-jlzg6.istio-system     SYNCED     SYNCED     SYNCED     NOT SENT     istiod-asm-193-2-664ccd5d95-w4fgd     1.9.3-asm.2
istio-ingressgateway-55c757dc94-vtmf2.istio-system     SYNCED     SYNCED     SYNCED     NOT SENT     istiod-asm-193-2-664ccd5d95-w4fgd     1.9.3-asm.2
```

NOTE: For ASM you will see two ingressgateways instead of one as with Istio OSS
default configuration (depending on the
[installation profile](https://istio.io/latest/docs/setup/additional-setup/config-profiles/)
selected)

As we install applications and configure Istio objects in the following tasks,
we will see how they show on this `proxy-status` info.

Note: If you see `EDS SYNCED` with a percentage, it is likely an older version
of the CLI being used since this information was removed as it was not
meaningful. For detail see
[Github Issue](https://github.com/istio/istio/pull/15028).

### Get details about Envoy proxies programming

Let’s see what an empty mesh looks like. Here we will be looking at the
programming for the Istio _ingressgateway_ as this is the only Envoy deployed on
the mesh at the moment.

> Envoy objects relationship:
>
> Listeners -> Routes -> Clusters -> Endpoints.

1.  Listener Discovery Service (LDS)

    ```shell {highlight="content:listeners"}
    $ istioctl pc listeners \
        $(kubectl get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system).istio-system
    ```

    Note: `proxy-config` can be shortened to `pc`

    Output:

    ``` {.no-copy}
    ADDRESS PORT  MATCH DESTINATION
    0.0.0.0 15021 ALL   Inline Route: /healthz/ready*
    0.0.0.0 15090 ALL   Inline Route: /stats/prometheus*
    ```

    Note: by default the istio-ingressgateway will start listening only on ports
    15090 and 15021.

2.  Route Discovery Service (RDS)

    ```shell {highlight="content:routes"}
    $ istioctl pc routes \
        $(kubectl get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system).istio-system
    ```

    Output:

    ``` {.no-copy}
    NOTE: This output only contains routes loaded via RDS.
    NAME     DOMAINS     MATCH                  VIRTUAL SERVICE
             *           /healthz/ready*
             *           /stats/prometheus*
    ```

    Let's look into this routes in greater detail:

    ```shell {highlight="content:routes"}
    $ istioctl pc routes \
        $(kubectl get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system).istio-system -o json
    ```

    Output:

    ``` {.no-copy}
    [
    {
        "virtualHosts": [
            {
                "name": "backend",
                "domains": [
                    "*"
                ],
                "routes": [
                    {
                        "match": {
                            "prefix": "/stats/prometheus"
                        },
                        "route": {
                            "cluster": "prometheus_stats"
                        }
                    }
                ]
            }
        ]
    },
    {
        "virtualHosts": [
            {
                "name": "backend",
                "domains": [
                    "*"
                ],
                "routes": [
                    {
                        "match": {
                            "prefix": "/healthz/ready"
                        },
                        "route": {
                            "cluster": "agent"
                        }
                    }
                ]
            }
        ]
    }
    ]
    ```

    Note: by default all proxies start with a route for prometheus. This is used
    for metrics.

3.  Cluster Discovery Service (CDS)

    ```shell {highlight="content:clusters"}
    $ istioctl proxy-config clusters \
        $(kubectl get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system).istio-system
    ```

    Expected output: entries for all existing services in the cluster, such as
    all istio control plane components but also kube-dns and others.

    Note that the `prometheus_stats` is static. It means it is not generated by
    service discovery (received from Pilot) but statically defined on
    [Envoy's Bootstrap Configuration](https://www.envoyproxy.io/docs/envoy/latest/api-v3/config/bootstrap/v3/bootstrap.proto).

    More details on the `prometheus_stats` cluster:

    ```shell {highlight="content:clusters"}
    $ istioctl proxy-config clusters \
        $(kubectl get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system).istio-system --fqdn prometheus_stats -o json
    ```

    Output:

    ```{.no-copy} {highlight="content:STATIC"}
    [
    {
        "name": "prometheus_stats",
        "type": "STATIC",
        "connectTimeout": "0.250s",
        "loadAssignment": {
            "clusterName": "prometheus_stats",
            "endpoints": [
                {
                    "lbEndpoints": [
                        {
                            "endpoint": {
                                "address": {
                                    "socketAddress": {
                                        "address": "127.0.0.1",
                                        "portValue": 15000
                                    }
                                }
                            }
                        }
                    ]
                }
            ]
        }
    }
    ]
    ```

4.  Endpoint Discovery Service (EDS)

    ```shell {highlight="content:endpoints"}
    $ istioctl pc endpoints \
        $(kubectl get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system).istio-system
    ```

    Expected output: see endoints (IP:PORT) for each service in the cluster.

    Checking the prometheus_stat endpoint will give details on its healhty
    status as well as some metrics:

    ```shell
    $ istioctl pc endpoints \
        $(kubectl get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system).istio-system \
            --cluster prometheus_stats -o json
    ```

    Output:

    ``` {.no-copy}
    [
    {
        "name": "prometheus_stats",
        "hostStatuses": [
            {
                "address": {
                    "socketAddress": {
                        "address": "127.0.0.1",
                        "portValue": 15000
                    }
                },
                "stats": [
                    {
                        "name": "cx_connect_fail"
                    },
                    {
                        "name": "cx_total"
                    },
                    {
                        "name": "rq_error"
                    },
                    {
                        "name": "rq_success"
                    },
                    {
                        "name": "rq_timeout"
                    },
                    {
                        "name": "rq_total"
                    },
                    {
                        "type": "GAUGE",
                        "name": "cx_active"
                    },
                    {
                        "type": "GAUGE",
                        "name": "rq_active"
                    }
                ],
                "healthStatus": {
                    "edsHealthStatus": "HEALTHY"
                },
                "weight": 1,
                "locality": {}
            }
        ],
        "circuitBreakers": {
            "thresholds": [
                {
                    "maxConnections": 1024,
                    "maxPendingRequests": 1024,
                    "maxRequests": 1024,
                    "maxRetries": 3
                },
                {
                    "priority": "HIGH",
                    "maxConnections": 1024,
                    "maxPendingRequests": 1024,
                    "maxRequests": 1024,
                    "maxRetries": 3
                }
            ]
        }
    }
    ]
    ```

    For this cluster we can see if it is currently healthy and other interesting
    data such as total number of requests, active connections and errors.

### Looking at logs on an empty Mesh

1.  Istiod logs

    ```shell
    $ kubectl logs -n istio-system \
        $(kubectl get -n istio-system pod \
          -l istio=istiod \
          -o jsonpath='{.items[0].metadata.name}') -c discovery | less
    ```

    Interesting logs:

    *   "info FLAG:" - startup flags
    *   "info mesh configuration" - comes from the istio ConfigMap
    *   json representation of the config. Example: bootstrap.ConfigArgs
    *   "Handling event add for pod" - discovering pods in the cluster
    *   "info ads" - programming a proxy

    Common errors during startup (OK if they don't persist):

    *   "Configuration not synced:"
    *   "failed to connect to {istio-galley.istio-system.svc:9901"
    *   "Failed to create a new MCP sink stream:"

    Common recurrent errors (OK,if more or less every half an hour):

    *   "transport: closing server transport due to maximum connection age."
    *   "transport: loopyWriter.run returning. connection error: desc =
        "transport is closing""
    *   "terminated rpc error: code = Canceled desc = context canceled"

    Istiod logs for programming the istio-ingressgateway:

    ```shell
    $ kubectl logs -n istio-system \
        $(kubectl get -n istio-system pod \
          -l istio=istiod \
          -o jsonpath='{.items[0].metadata.name}') \
            -c discovery --tail 50 \
            | grep istio-ingressgateway | grep ads
    ```

2.  istio-ingressgateway logs

    ```shell
    $ kubectl logs -n istio-system \
        $(kubectl get -n istio-system pod \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}')
    ```

## Deploy a sample app on the cluster adding it to the Istio Mesh

> Reference:
> [Istio: Deploying the application](https://istio.io/docs/examples/bookinfo/#deploying-the-application)

### Enable automatic sidecar injection on the default namespace

> Reference:
> [Istio: Automatic sidecar injection](https://istio.io/docs/setup/additional-setup/sidecar-injection/#automatic-sidecar-injection)

Note: With ASM, the WebHook needed for sidecar injection is pre-configured and
enabled by default.

1.  Checking the sidecar injector setup

    A mutating webhook intercepts all pods creation in namespaces where the
    namespace label is set.

    > Reference:
    > [Mutating Webhook](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/#mutatingadmissionwebhook)

    ```shell
    $ kubectl get MutatingWebhookConfiguration -l app=sidecar-injector -o yaml
    ```

    Since version 1.5, the istio-sidecar-injector service running on Istiod will
    be called for every pod created. Let's review the deployment configuration:

    ```shell
    $ kubectl get  deploy -l app=istiod -n istio-system -o yaml
    ```

    Looking at the sidecar-injector config, we can see a template and final
    values generated. Looking specifically at proxy config:

    ```shell
    $ kubectl get cm $(kubectl get cm -n istio-system |grep -Po "istio-sidecar-injector[-\w]+") \
      -n istio-system \
      -o jsonpath={.data.values} | jq .global.proxy
    ```

    For example you can see default CPU requests that will be set on sidecars.

2.  Enable Istio injection on default namespace:

    The default namespace does not have automatic sidecar injection enabled by
    default. In order to start using Istio with automatic sidecar injection, one
    needs to enable injection on the desired namespace. Here we will enable it
    on the default namespace:

    ```shell
    $ export REVISION=$(kubectl -n istio-system get pods -l app=istiod --show-labels|grep -Po "(asm-\d+-\d+)"|head -n1)
    $ kubectl label namespace default istio-injection- istio.io/rev=${REVISION} --overwrite
    ```

3.  Check the sidecar injection on all namespaces

    ```shell
    $ kubectl get namespace -L istio.io/rev
    ```

    ```none {.no-copy highlight="lines:3"}
    NAME              STATUS   AGE    REV
    asm-system        Active   79m
    default           Active   121m   asm-193-2
    gke-connect       Active   81m
    istio-system      Active   80m
    kube-node-lease   Active   121m
    kube-public       Active   121m
    kube-system       Active   121m
    ```

    > **Note about manual sidecar injection**
    >
    > The `istioctl` tool has a subcommand that facilitates manual sidecar
    > injection.
    >
    > For example, given a deployment yaml file, a deployment can be updated to
    > include injected sidecar with the following command:
    >
    > ```shell
    > $ istioctl kube-inject -f deployment.yaml -o deployment-injected.yaml
    > ```
    >
    > A popular usage of this command is the “on-the-fly” update of a resource
    > as follows:
    >
    > ```shell
    > $ kubectl apply -f <(istioctl kube-inject -f <resource.yaml>)
    > ```

### Deploy a sample app

<!--* pragma: { seclinter_this_is_fine: true } *-->

1.  Deploy an app

    ```shell
    $ export ISTIO_VERSION=$(kubectl get pods \
       -l istio=istiod -n istio-system \
       -o jsonpath='{.items[0].spec.containers[0].image}' \
         | cut -d ':' -f2 \
         | cut -d '-' -f1 )
    $ curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
    $ cd istio-$ISTIO_VERSION
    $ kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
    ```

<!--* pragma: { seclinter_this_is_fine: false } *-->

2.  Verify the deployment

    ```shell
    $ kubectl get svc,pods
    ```

    ```none {.no-copy highlight="content:2/2"}
    NAME                  TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
    service/details       ClusterIP   10.64.0.118    <none>        9080/TCP   49s
    service/kubernetes    ClusterIP   10.64.0.1      <none>        443/TCP    126m
    service/productpage   ClusterIP   10.64.13.25    <none>        9080/TCP   48s
    service/ratings       ClusterIP   10.64.14.26    <none>        9080/TCP   49s
    service/reviews       ClusterIP   10.64.10.162   <none>        9080/TCP   49s

    NAME                                  READY   STATUS    RESTARTS   AGE
    pod/details-v1-66b6955995-svbgz       2/2     Running   0          49s
    pod/productpage-v1-5d9b4c9849-md987   2/2     Running   0          48s
    pod/ratings-v1-fd78f799f-662k9        2/2     Running   0          49s
    pod/reviews-v1-6549ddccc5-8ln47       2/2     Running   0          49s
    pod/reviews-v2-76c4865449-z9d7r       2/2     Running   0          48s
    pod/reviews-v3-6b554c875-t87th        2/2     Running   0          48s
    ```

    Note: each pod has two containers (`2/2` under `READY`). This is because
    each pod will have one container for the workload app and one container for
    the Envoy sidecar proxy.

3.  Check the internal communication between pods

    For example, from the **ratings** pod reach **product** page:

    ```shell
    $ kubectl exec -it \
        $(kubectl get pod \
          -l app=ratings \
          -o jsonpath='{.items[0].metadata.name}') \
          -c ratings -- \
          curl productpage:9080/productpage \
          | grep -o "<title>.*</title>" ; echo
    ```

4.  Check the mesh

    ```shell
    $ istioctl ps
    ```

    Each pod injected with a sidecar shows on the listing.

### Look at the ingress gateway

1.  Listeners are still empty:

    ```shell
    $ istioctl pc listeners \
        $(kubectl get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system).istio-system
    ```

2.  Routes did not change:

    ```shell
    $ istioctl pc routes \
        $(kubectl get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system).istio-system
    ```

3.  Notice that clusters now show the application services we deployed:

    ```shell
    $ istioctl pc clusters \
        $(kubectl get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system).istio-system
    ```

4.  Endpoints now show the application services:

    ```shell
    $ istioctl pc endpoints \
        $(kubectl get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system).istio-system | grep default
    ```

### Look at the application proxy configuration for the productpage deployment

All application pods were injected with an Envoy sidecar and some configuration
was automatically loaded to those proxies based on the mesh default
configuration and the kubernetes services that were defined.

Comparing the xDS config for the application Envoy with the ingress gateway

1.  Obtain podIP and containerPort for productpage:

    ```shell
    $ POD_IP=$(kubectl get pod \
        -l app=productpage \
        -o jsonpath='{.items[0].status.podIP}')

    $ CONTAINER_PORT=$(kubectl get pod \
        -l app=productpage \
        -o jsonpath='{.items[0].spec.containers[0].ports[].containerPort}')
    ```

2.  The app has listeners for its own service, envoy and a number of other
    services ports in the cluster:

    ```shell
    $ istioctl pc listeners \
        $(kubectl get pod \
          -l app=productpage \
          -o jsonpath='{.items[0].metadata.name}') \
          | grep -z "$POD_IP\|$CONTAINER_PORT"
    ```

    Inbound listener for podIP and containerPort.

3.  The app has inbound routes for its own service and a number of other routes
    for services in the mesh

    ```shell
    $ istioctl pc routes \
        $(kubectl get pod \
          -l app=productpage -o jsonpath='{.items[0].metadata.name}')
    ```

4.  We can expand a route config to see how it is configured in details with the
    following command:

    ```shell
    $ istioctl pc routes \
        $(kubectl get pod \
          -l app=productpage \
          -o jsonpath='{.items[0].metadata.name}') \
          --name 9080 -o json
    ```

5.  Clusters are similar to the ingress gateway:

    ```shell
    $ istioctl pc clusters \
        $(kubectl get pod \
          -l app=productpage -o jsonpath='{.items[0].metadata.name}')
    ```

6.  Endpoints are similar as the ingress gateway

    ```shell
    $ istioctl pc endpoints \
        $(kubectl get pod \
          -l app=productpage -o jsonpath='{.items[0].metadata.name}')
    ```

7.  Reviewing Istiod logs

    ```shell
    $ kubectl logs -n istio-system \
        $(kubectl get -n istio-system pod \
          -l istio=istiod -o jsonpath='{.items[0].metadata.name}') \
          -c discovery --tail 50 | grep ingress
    ```

    We see the number of clusters and endpoints increased but listeners is still
    set to zero.

## Define ingress rules to enable external access to the app

> Reference:
> [Istio: Ingress Gateways](https://istio.io/docs/tasks/traffic-management/ingress/ingress-control/)

In this task, we will configure access to the sample application from outside of
the cluster.

The ingress gateway is exposed via NLB by default. For example, if we look at
the `istio-ingressgateway` service, we will see it has an external IP.

```shell
$ kubectl get svc -n istio-system -l istio=ingressgateway
```

Reaching the istio-ingressgateway external IP:

```shell
$ curl $(kubectl -n istio-system get service istio-ingressgateway \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

The command returns `Connection refused` since there is no Istio programming for
the ingress gateway to route requests to the sample app deployed. We will create
rules for that in the next steps.

### Creating the Gateway object

> Reference:
> [Istio: Gateway](https://istio.io/docs/reference/config/networking/v1alpha3/gateway/)

1.  The following gateway object configures the `ingressgateway` deployment to
    accept incoming connections to port 80 with host set to productpage.com.

    ```shell
    $ kubectl apply -f - <<EOF
    apiVersion: networking.istio.io/v1alpha3
    kind: Gateway
    metadata:
      name: bookinfo-gateway
    spec:
      selector:
        istio: ingressgateway # use istio default controller
      servers:
      - port:
          number: 80
          name: http
          protocol: HTTP
        hosts:
        - "productpage.com"
    EOF
    ```

2.  The ingress gateway now has a listener for port 80

    ```shell
    $ istioctl pc listeners \
        $(kubectl get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system).istio-system
    ```

3.  And a route for http 80 was also added

    ```shell
    $ istioctl pc routes \
        $(kubectl get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system).istio-system
    ```

4.  The route defines a default 404 response

    ```shell
    $ istioctl pc routes \
        $(kubectl get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system).istio-system \
          --name http.80 -o json
    ```

5.  At this point, we will get 404 when reaching the ingress gateway instead of
    `Connection refused`:

    ```shell
    $ curl -I $(kubectl -n istio-system get service istio-ingressgateway \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    ```

    So basically we just programmed the envoy from the `istio-ingressgateway` to
    listen on port 80 and to return 404 by default.

### Creating the VirtualService object

> Reference:
> [Istio: Virtual Service](https://istio.io/docs/reference/config/networking/v1alpha3/virtual-service/)

What allows us to program the URL mappings on the ingress gateway with our
application backends is the VirtualService object.

1.  The following VirtualService programs a set of URIs which maps to the
    productpage application backend.

    ```shell
    $ kubectl apply -f - <<EOF
    apiVersion: networking.istio.io/v1alpha3
    kind: VirtualService
    metadata:
      name: bookinfo
    spec:
      hosts:
      - "*"
      gateways:
      - bookinfo-gateway
      http:
      - match:
        - uri:
            exact: /productpage
        - uri:
            prefix: /static
        - uri:
            exact: /login
        - uri:
            exact: /logout
        - uri:
            prefix: /api/v1/products
        route:
        - destination:
            host: productpage
            port:
              number: 9080
    EOF
    ```

2.  Reaching the gateway now on /product URI:

    ```shell
    $ curl -I $(kubectl -n istio-system get service istio-ingressgateway \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}')/productpage
    ```

    We still get a 404. Let's review the config.

3.  Let's review the logs

    On the istio-ingressgateway:

    ```shell
    $ kubectl logs -n istio-system \
        $(kubectl get -n istio-system pod \
          -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}') \
          --tail 10
    ```

    On Istiod

    ```shell
    $ kubectl logs -n istio-system \
        $(kubectl get -n istio-system pod \
          -l istio=istiod -o jsonpath='{.items[0].metadata.name}') \
          -c discovery --tail 50 \
          | grep istio-ingressgateway | grep ads
    ```

4.  Let's see if Pilot, on Istiod, took the configuration

    ```shell
    $ kubectl exec -it \
        $(kubectl get pod \
          -l istio=istiod -o jsonpath='{.items[0].metadata.name}' -n istio-system) \
            -n istio-system -c discovery -- \
            curl -s localhost:15014/debug/configz > /tmp/pilot_configz

    $ less /tmp/pilot_configz
    ```

    The output shows that Istiod got the configuration of the Gateway and
    VirtualService we created.

    Check if it has generated a config for the istio-ingressgateway

    ```shell
    $ REMOTE_PROXY=$(kubectl get -n istio-system pod \
        -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}')

    $ kubectl exec -it \
        $(kubectl get pod \
          -l istio=istiod \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system) \
            -n istio-system -c discovery -- \
            curl -s localhost:15014/debug/config_dump?proxyID=$REMOTE_PROXY.istio-system > /tmp/pilot_config_for_a_remote_proxy

    $ less /tmp/pilot_config_for_a_remote_proxy
    ```

    Compare with the config received by the istio-ingessgateway

    ```shell
    $ kubectl -n istio-system exec -ti \
        $(kubectl -n istio-system get pod \
          -l istio=ingressgateway -o jsonpath='{.items[0].metadata.name}') \
            -c istio-proxy -- \
            curl -s localhost:15000/config_dump > /tmp/proxy_config_dump

    $ less /tmp/proxy_config_dump
    ```

5.  Reviwing the listeners for the istio-ingressgateway

    ```shell
    $ istioctl pc listeners \
        $(kubectl get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system).istio-system \
            --port 80 -o json
    ```

    Configured with 0.0.0.0_80. Indeed, we can establish the connection.

6.  Looking at the `http.80` route now, we see it is linked to the productpage
    backend:

    ```shell
    $ istioctl pc routes \
        $(kubectl get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}' \
          -n istio-system).istio-system \
            --name http.80 -o json
    ```

    Notice the VirtualHosts:

    ``` {.no-copy}
    "virtualHosts": [
        {
            "name": "productpage.com:80",
            "domains": [
                    "productpage.com",
                    "productpage.com:80"
             ],
    ```

    Since productpage.com is under hosts in the Gateway, that host is required
    in order to access the app.

### Reach the app from outside the cluster via productpage.com

1.  Form the app URL with the gateway endpoint

    ```shell
    $ export INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway \
        -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    $ export INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway \
        -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
    $ export GATEWAY_URL=productpage.com/productpage
    ```

2.  Reach the app from outside the cluster

    ```shell
    $ curl -s --resolve productpage.com:$INGRESS_PORT:$INGRESS_HOST \
        http://${GATEWAY_URL} | grep -o "<title>.*</title>"
    ```

    > Note: the response header shows the request is served by Envoy
    >
    > ```shell
    > $ curl --resolve productpage.com:$INGRESS_PORT:$INGRESS_HOST -D - -o/dev/null -s http://${GATEWAY_URL}
    > ```

3.  Checking the objects created

    ```shell
    $ kubectl get gateway
    $ kubectl get gateway bookinfo-gateway -o yaml
    $ kubectl get virtualservice
    $ kubectl get virtualservice bookinfo -o yaml
    ```

Note: modify the hosts value and compare the changes in listeners and routes as
well as the results of the curl command.

### Reviewing the istio-ingressgateway logs

1.  Enable debugging logs

    ```shell
    $ kubectl exec -it -n istio-system \
        $(kubectl -n istio-system get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}') -- \
            curl -s -X POST localhost:15000/logging?level=debug
    ```

2.  Leave a loop of bad and good requests running

    ```shell
    $ while true;
      do
        curl --resolve productpage.com:$INGRESS_PORT:$INGRESS_HOST \
          -D - -o/dev/null -s http://${GATEWAY_URL};
        sleep 1;
        curl -D - -o/dev/null -s http://$INGRESS_HOST/productpage;
      done
    ```

3.  On a different tab, capture the istio-ingressgateway logs

    ```shell
    $ kubectl logs -n istio-system \
        $(kubectl get -n istio-system pod \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}') \
            --tail 10 -f
    ```

    Output for bad requests:

    ``` {.no-copy highlight="content:route_not_found"}
    2021-04-24T10:35:03.073426Z     debug   envoy http      [C4106][S5137472549020191810] request end stream
    2021-04-24T10:35:03.073521Z     debug   envoy router    [C4106][S5137472549020191810] no cluster match for URL '/productpage'
    2021-04-24T10:35:03.073538Z     debug   envoy http      [C4106][S5137472549020191810] Sending local reply with details route_not_found
    2021-04-24T10:35:03.073646Z     debug   envoy http      [C4106][S5137472549020191810] encoding headers via codec (end_stream=true):
    ':status', '404'
    'date', 'Wed, 01 Jul 2020 21:30:50 GMT'
    'server', 'istio-envoy'
    ```

    Output for good requests:

    ``` {.no-copy highlight="content:match for URL"}
    2021-04-26T08:29:40.797601Z     debug   envoy http      [C350][S15104120645444447408] request end stream
    2021-04-26T08:29:40.797708Z     debug   envoy router    [C350][S15104120645444447408] cluster 'outbound|9080||productpage.default.svc.cluster.local' match for URL '/productpage'
    2021-04-26T08:29:40.797750Z     debug   envoy router    [C350][S15104120645444447408] router decoding headers:
    ':authority', 'productpage.com'
    ':path', '/productpage'
    ':method', 'GET'
    ':scheme', 'https'
    'user-agent', 'curl/7.64.0'
    'accept', '*/*'
    'x-forwarded-for', '10.60.1.1'
    'x-forwarded-proto', 'http'
    'x-envoy-internal', 'true'
    'x-request-id', '6c05b8c1-185e-4273-97c5-0aabb20d8fe4'
    'x-envoy-decorator-operation', 'productpage.default.svc.cluster.local:9080/productpage'
    'x-envoy-peer-metadata',     'ChQKDkFQUF9DT05UQUlORVJTEgIaAApECgpDTFVTVEVSX0lEEjYaNGNuLWdyaWFsMy1wcm9qZWN0LWV1cm9wZS1jZW50cmFsMi1hLWlzdGlvLXBsYXlncm91bmQKHgoNSVNUSU9fVkVSU0lPThINGgsxLjkuMy1hc20uMgrEAwoGTEFCRUxTErkDKrYDCh0KA2FwcBIWGhRpc3Rpby1pbmdyZXNzZ2F0ZXdheQoTCgVjaGFydBIKGghnYXRld2F5cwoUCghoZXJpdGFnZRIIGgZUaWxsZXIKNgopaW5zdGFsbC5vcGVyYXRvci5pc3Rpby5pby9vd25pbmctcmVzb3VyY2USCRoHdW5rbm93bgoZCgVpc3RpbxIQGg5pbmdyZXNzZ2F0ZXdheQobCgxpc3Rpby5pby9yZXYSCxoJYXNtLTE5My0yCjAKG29wZXJhdG9yLmlzdGlvLmlvL2NvbXBvbmVudBIRGg9JbmdyZXNzR2F0ZXdheXMKIQoRcG9kLXRlbXBsYXRlLWhhc2gSDBoKNTVjNzU3ZGM5NAoSCgdyZWxlYXNlEgcaBWlzdGlvCjkKH3NlcnZpY2UuaXN0aW8uaW8vY2Fub25pY2FsLW5hbWUSFhoUaXN0aW8taW5ncmVzc2dhdGV3YXkKMgojc2VydmljZS5pc3Rpby5pby9jYW5vbmljYWwtcmV2aXNpb24SCxoJYXNtLTE5My0yCiIKF3NpZGVjYXIuaXN0aW8uaW8vaW5qZWN0EgcaBWZhbHNlCh8KB01FU0hfSUQSFBoScHJvai0xMDAxNjMwMzgwMzk1Ci8KBE5BTUUSJxolaXN0aW8taW5ncmVzc2dhdGV3YXktNTVjNzU3ZGM5NC1jYnRxYgobCglOQU1FU1BBQ0USDhoMaXN0aW8tc3lzdGVtCl0KBU9XTkVSElQaUmt1YmVybmV0ZXM6Ly9hcGlzL2FwcHMvdjEvbmFtZXNwYWNlcy9pc3Rpby1zeXN0ZW0vZGVwbG95bWVudHMvaXN0aW8taW5ncmVzc2dhdGV3YXkK7QIKEVBMQVRGT1JNX01FVEFEQVRBEtcCKtQCCiwKE2djcF9nY2VfaW5zdGFuY2VfaWQSFRoTNDMyMjU4MzU4MjQyMTUzNTU1MAoqChRnY3BfZ2tlX2NsdXN0ZXJfbmFtZRISGhBpc3Rpby1wbGF5Z3JvdW5kCooBChNnY3BfZ2tlX2NsdXN0ZXJfdXJsEnMacWh0dHBzOi8vY29udGFpbmVyLmdvb2dsZWFwaXMuY29tL3YxL3Byb2plY3RzL2dyaWFsMy1wcm9qZWN0L2xvY2F0aW9ucy9ldXJvcGUtY2VudHJhbDItYS9jbHVzdGVycy9pc3Rpby1wbGF5Z3JvdW5kCiMKDGdjcF9sb2NhdGlvbhITGhFldXJvcGUtY2VudHJhbDItYQofCgtnY3BfcHJvamVjdBIQGg5ncmlhbDMtcHJvamVjdAolChJnY3BfcHJvamVjdF9udW1iZXISDxoNMTAwMTYzMDM4MDM5NQonCg1XT1JLTE9BRF9OQU1FEhYaFGlzdGlvLWluZ3Jlc3NnYXRld2F5'
    'x-envoy-peer-metadata-id', 'router~10.60.1.7~istio-ingressgateway-55c757dc94-cbtqb.istio-system~istio-system.svc.cluster.local'
    'x-envoy-attempt-count', '1'
    'x-b3-traceid', '592684309259c81b0d1cad44daba2c00'
    'x-b3-spanid', '0d1cad44daba2c00'
    'x-b3-sampled', '0'

    2021-04-26T08:29:40.797759Z     debug   envoy pool      [C222] using existing connection
    2021-04-26T08:29:40.797763Z     debug   envoy pool      [C222] creating stream
    2021-04-26T08:29:40.797786Z     debug   envoy router    [C350][S15104120645444447408] pool ready
    2021-04-26T08:29:40.797819Z     debug   envoy connection        [C349] remote early close
    2021-04-26T08:29:40.797824Z     debug   envoy connection        [C349] closing socket: 0
    2021-04-26T08:29:40.797910Z     debug   envoy conn_handler      [C349] adding to cleanup list
    2021-04-26T08:29:40.817905Z     debug   envoy router    [C350][S15104120645444447408] upstream headers complete: end_stream=false
    2021-04-26T08:29:40.818000Z     debug   envoy http      [C350][S15104120645444447408] encoding headers via codec (end_stream=false):
    ':status', '200'
    'content-type', 'text/html; charset=utf-8'
    'content-length', '4183'
    'server', 'istio-envoy'
    'date', 'Mon, 26 Apr 2021 08:29:40 GMT'
    'x-envoy-upstream-service-time', '20'
    ```

4.  Rollback logs to the default level

    ```shell
    $ kubectl exec -it -n istio-system \
        $(kubectl -n istio-system get pods \
          -l istio=ingressgateway \
          -o jsonpath='{.items[0].metadata.name}') -- \
            curl -s -X POST localhost:15000/logging?level=info
    ```

## Access an external service from inside the mesh

> Reference:
> [Istio: Accessing External Services](https://istio.io/docs/tasks/traffic-management/egress/egress-control/)

Since Istio 1.1, Envoy is configured by default as a passthrough for requests to
external services.

1.  To confirm that, let’s access an external http service from a pod:

    ```shell
    $ kubectl exec -it $(kubectl get pod \
        -l app=ratings -o jsonpath='{.items[0].metadata.name}') \
          -c ratings -- curl -I httpbin.org
    ```

    Note: A ServiceEntry would be required if the
    `global.outboundTrafficPolicy.mode` was set to `REGISTRY_ONLY` instead of
    `ALLOW_ANY`. On Istio 1.0.x `REGISTRY_ONLY` was default but since 1.1.x it
    is now `ALLOW_ANY`. When using Isito OSS, users can overwrite the release
    default and configure the global policy they prefer.

2.  Based on this global policy, all sidecar proxies are configured with
    `PassthroughCluster` which forwards the request to its `ORIGINAL_DST`. For
    example, see:

    ```shell
    $ istioctl pc clusters $(kubectl get pod \
        -l app=productpage -o jsonpath='{.items[0].metadata.name}') \
          --fqdn PassthroughCluster
    ```

3.  This means that if the `PassthroughCluster` does not show on the output of
    ‘istioctl pc clusters’, likely `REGISTRY_ONLY` is configured for
    `global.outboundTrafficPolicy.mode`.

    It is possible to verify that on a cluster by checking the Istio ConfigMap
    on `istio-system` namespace:

    ```shell
    $ kubectl -n istio-system get configmap $(kubectl get cm -n istio-system |grep -Po "istio-asm[-\w]+") \
      -o=jsonpath='{.data.mesh}' | grep outboundTrafficPolicy -A 1
    ```

## Force traffic to go through the Egress Gateway

> Reference:
> [Istio: Egress Gateways](https://istio.io/docs/tasks/traffic-management/egress/egress-gateway/),
> [Using Anthos Service Mesh egress gateways on GKE clusters](https://cloud.google.com/service-mesh/docs/security/egress-gateway-gke-tutorial)

#### Upgrade the control plane to install the egress gateway

1.  Be sure to have the `install_asm` script in the current working directory:

    ```shell
    $ ls install_asm
    ```

2.  Force an upgrade of the control plane to install ASM with the egress gateway
    enabled in the IstioOperator:

    ```shell
    $ ./install_asm \
     --project_id ${PROJECT_ID} \
     --cluster_name ${CLUSTER_NAME} \
     --cluster_location ${ZONE} \
     --mode install \
     --enable_all \
     --enable-registration \
     --option revisioned-istio-ingressgateway \
     --option egressgateways \
     --force_same_version
    ```

3.  Checking the egress gateway

    ```shell
    $ kubectl get pods -n istio-system
    $ kubectl describe pod -l app=istio-egressgateway -n istio-system
    ```

    Note: this is just an Envoy proxy similar to the ingress gateway

4.  The egress gateway also shows on the mesh overview

    ```shell
    $ istioctl ps
    ```

### Make a request directly to httpbin.org

1.  Make a request

    ```shell
    $ kubectl exec -it $(kubectl get pod \
        -l app=ratings -o jsonpath='{.items[0].metadata.name}') \
          -c ratings -- curl -I http://httpbin.org
    ```

2.  Checking stats on the egress gateway

    > Reference:
    > https://www.envoyproxy.io/docs/envoy/v1.5.0/configuration/cluster_manager/cluster_stats

    ```shell
    $ kubectl exec -it $(kubectl get pod \
        -l app=istio-egressgateway \
        -o jsonpath='{.items[0].metadata.name}' \
        -n istio-system) \
          -n istio-system -c istio-proxy -- \
            curl -s localhost:15000/clusters | grep httpbin | grep total
    ```

    The output should be empty because the sidecars by default access the
    external endpoints directly.

### Create a ServiceEntry for httpbin.org

1.  Create a ServiceEntry

    ```shell
    $ kubectl apply -f - <<EOF
    apiVersion: networking.istio.io/v1alpha3
    kind: ServiceEntry
    metadata:
      name: httpbin
    spec:
      hosts:
      - httpbin.org
      ports:
      - number: 80
        name: http
        protocol: HTTP
      resolution: DNS
    EOF
    ```

2.  Check the stats again and see the outbound to httpbin.org has been
    programmed but the stats are still at zero connections:

    ```shell
    $ kubectl exec -it $(kubectl get pod \
        -l app=istio-egressgateway \
        -o jsonpath='{.items[0].metadata.name}' \
        -n istio-system) \
          -n istio-system -c istio-proxy -- \
            curl -s localhost:15000/clusters | grep httpbin | grep total
    ```

3.  Check the egress gateway programming:

    ```shell
    $ istioctl pc clusters $(kubectl get pods \
        -l istio=egressgateway \
        -o jsonpath='{.items[0].metadata.name}' \
        -n istio-system).istio-system | grep httpbin
    ```

    ```shell
    $ istioctl pc endpoints $(kubectl get pods \
        -l istio=egressgateway \
        -o jsonpath='{.items[0].metadata.name}' \
        -n istio-system).istio-system | grep httpbin
    ```

4.  Note that listeners and routes are still empty:

    ```shell
    $ istioctl pc listeners $(kubectl get pods \
        -l istio=egressgateway \
        -o jsonpath='{.items[0].metadata.name}' \
        -n istio-system).istio-system | grep httpbin
    ```

    ```shell
    $ istioctl pc routes $(kubectl get pods \
        -l istio=egressgateway \
        -o jsonpath='{.items[0].metadata.name}' \
        -n istio-system).istio-system | grep httpbin
    ```

### Create Gateway and DestinationRule

1.  Create Gateway and DestinationRule

    ```shell
    $ kubectl apply -f - <<EOF
    apiVersion: networking.istio.io/v1alpha3
    kind: Gateway
    metadata:
      name: istio-egressgateway
    spec:
      selector:
        istio: egressgateway
      servers:
      - port:
          number: 80
          name: http
          protocol: HTTP
        hosts:
        - httpbin.org
    ---
    apiVersion: networking.istio.io/v1alpha3
    kind: DestinationRule
    metadata:
      name: egressgateway-for-httpbin
    spec:
      host: istio-egressgateway.istio-system.svc.cluster.local
      subsets:
      - name: httpbin
    EOF
    ```

2.  This creates a listener and route for port 80 on the egress gateway proxy

    ```shell
    $ istioctl pc listeners $(kubectl get pods \
        -l istio=egressgateway \
        -o jsonpath='{.items[0].metadata.name}' \
        -n istio-system).istio-system
    ```

    ```shell
    $ istioctl pc routes $(kubectl get pods \
        -l istio=egressgateway \
        -o jsonpath='{.items[0].metadata.name}' \
        -n istio-system).istio-system
    ```

3.  However the default route created for the egress gateway is just the default
    404 for port 80.

    ```shell
    $ istioctl pc routes $(kubectl get pods \
        -l istio=egressgateway \
        -o jsonpath='{.items[0].metadata.name}' \
        -n istio-system).istio-system --name http.80 -o json
    ```

4.  Reaching again the endpoint and checking the stats on the egress gateway
    will still show 0 connections:

    ```shell
    $ kubectl exec -it $(kubectl get pod \
        -l app=ratings -o jsonpath='{.items[0].metadata.name}') \
          -c ratings -- curl -I http://httpbin.org
    ```

    ```shell
    $ kubectl exec -it $(kubectl get pod \
        -l app=istio-egressgateway \
        -o jsonpath='{.items[0].metadata.name}' \
        -n istio-system) \
          -n istio-system -c istio-proxy -- \
            curl -s localhost:15000/clusters | grep httpbin | grep total
    ```

### Create a VirtualService

1.  This configures the mesh to send traffic to the egress gateway when the
    destination is httpbin.org and the egress gateway to send it to httpbin.org.

    ```shell
    $ kubectl apply -f - <<EOF
    apiVersion: networking.istio.io/v1alpha3
    kind: VirtualService
    metadata:
      name: httpbin-http-through-egress-gateway
    spec:
      hosts:
      - httpbin.org
      gateways:
      - istio-egressgateway
      - mesh
      http:
      - match:
        - gateways:
          - mesh
          port: 80
        route:
        - destination:
            host: istio-egressgateway.istio-system.svc.cluster.local
            subset: httpbin
            port:
              number: 80
          weight: 100
      - match:
        - gateways:
          - istio-egressgateway
          port: 80
        route:
        - destination:
            host: httpbin.org
            port:
              number: 80
          weight: 100
    EOF
    ```

2.  Both the app and the egress gateway now see a route that forwards requests
    to httpbin.org via the istio-egressgateway

    ```shell
    $ istioctl pc routes $(kubectl get pod \
        -l app=ratings -o jsonpath='{.items[0].metadata.name}') \
          --name 80 -o json | grep httpbin
    ```

    The egressgateway route now links with the outbound httpbin.org cluster:

    ```shell
    $ istioctl pc routes $(kubectl get pods \
        -l istio=egressgateway \
        -o jsonpath='{.items[0].metadata.name}' \
        -n istio-system).istio-system \
          --name http.80 -o json
    ```

### Make requests to httpbin.org through the egress gateway

1.  Make requests to httpbin.org

    ```shell
    $ kubectl exec -it $(kubectl get pod \
        -l app=ratings -o jsonpath='{.items[0].metadata.name}') \
          -c ratings -- curl -I http://httpbin.org
    ```

2.  Checking connections are going through the egress gateway

    ```shell
    $ kubectl exec -it $(kubectl get pod \
        -l app=istio-egressgateway \
        -o jsonpath='{.items[0].metadata.name}' \
        -n istio-system) \
          -n istio-system -c istio-proxy -- \
            curl -s localhost:15000/clusters | grep httpbin | grep total
    ```

    Example output:

    ```none {.no-copy highlight="lines:3"}
    outbound|80||httpbin.org::54.91.118.50:80::cx_total::0
    outbound|80||httpbin.org::54.91.118.50:80::rq_total::0
    outbound|80||httpbin.org::34.231.30.52:80::cx_total::0
    outbound|80||httpbin.org::34.231.30.52:80::rq_total::0
    outbound|80||httpbin.org::54.166.163.67:80::cx_total::0
    outbound|80||httpbin.org::54.166.163.67:80::rq_total::0
    outbound|80||httpbin.org::34.199.75.4:80::cx_total::1
    outbound|80||httpbin.org::34.199.75.4:80::rq_total::1
    ```


## Cleanup

```shell
terraform destroy -var-file tf-vars.tfvars -auto-approve
```
