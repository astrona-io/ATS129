# Choose Where Chains Stores Provenance

A provenance statement that nobody can reach does not help an audit. `artifacts.taskrun.storage` decides where Chains writes it, and the answer to "can an auditor read it" depends on that one key. This part reads the statement in the two backends that need no extra service, `tekton` and `oci`, then lists the keys of the others.

## The storage key takes a list

The value of `artifacts.taskrun.storage` is a comma-separated list of backends. Chains writes the same signed statement to every backend in the list:

| Backend | Where the statement goes | Extra settings |
| --- | --- | --- |
| `tekton` | Annotations on the TaskRun (the default) | None |
| `oci` | An attestation next to the image in the registry | `storage.oci.repository`, `storage.oci.repository.insecure` |
| `gcs` | A Google Cloud Storage bucket | `storage.gcs.bucket` |
| `docdb` | A document database | `storage.docdb.url` |
| `grafeas` | A Grafeas server | `storage.grafeas.projectid`, `storage.grafeas.noteid` |
| `archivista` | An Archivista server | `storage.archivista.url` |

The last four need a service you run or buy. This module works with the first two, which the playground has. The keys of the others are the ones to recognise on an exam.

## What the tekton backend writes

With the default storage, a handled TaskRun carries a set of annotations with the run's UID in the name. Read them on a run from the previous part:

<!-- astrona:playground:renew -->

```sh
TR="$(kubectl get taskrun -n starfleet -o jsonpath='{.items[0].metadata.name}')"
kubectl get taskrun "$TR" -n starfleet -o yaml | grep -o 'chains.tekton.dev/[a-z0-9-]*'
```

If your playground has no run yet, create the key, the configuration and the Task from the previous part first, then run the Task once. The annotation names are these:

| Annotation | Content |
| --- | --- |
| `chains.tekton.dev/signed` | `true` when Chains finished, `failed` when it gave up |
| `chains.tekton.dev/retries` | How many times Chains tried again |
| `chains.tekton.dev/payload-taskrun-<uid>` | The statement, base64-encoded |
| `chains.tekton.dev/signature-taskrun-<uid>` | The signature, base64-encoded |
| `chains.tekton.dev/cert-taskrun-<uid>` | The certificate, only with a certificate signer |
| `chains.tekton.dev/chain-taskrun-<uid>` | The certificate chain, only with a certificate signer |

The annotations live as long as the TaskRun. When the Pruner deletes the TaskRun, the statement is gone with it. That is the weakness of `tekton` storage as the only backend, and it connects this module to the Pruner module: a cluster that prunes runs must store provenance somewhere else first.

## What the oci backend writes

Add `oci` to the list and `kubectl apply` the ConfigMap with the keys you need. Chains then also attaches an attestation to the image the run built, using the results `IMAGE_URL` and `IMAGE_DIGEST`:

```sh
cat <<'YAML' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: chains-config
  namespace: tekton-chains
data:
  artifacts.taskrun.format: slsa/v2alpha4
  artifacts.taskrun.storage: tekton,oci
  artifacts.oci.storage: oci
  transparency.enabled: "false"
  storage.oci.repository.insecure: "true"
YAML
tkn task start build-image -n starfleet --param image=registry.localtest.me:5001/starfleet/crew --param tag=1.0.2 --showlog
```

When the run is signed, list the tags of the repository. The attestation and the signature are tags that start with `sha256-` and end with `.att` and `.sig`:

```sh
kubectl exec -n workstation deploy/workstation -- regctl tag ls registry.localtest.me:5001/starfleet/crew
```

Compare this run with the one before it. The earlier run has annotations only. The new run has the annotations and the registry attestation, and both hold the same statement.

## Where the attestation lands

By default the attestation goes into the same repository as the image. The key `storage.oci.repository` changes that. When it is set, for example to `registry.localtest.me:5001/starfleet/attestations`, Chains writes the signatures and attestations to that repository instead. Use it when the image repository is pulled by many consumers and you want the provenance in a repository with tighter write access. A verifier then has to look in the second repository, so write the choice down.

## Which backend for which question

A short guide for the choice:

1. Quick look by an operator who has cluster access: `tekton` is enough.
2. An auditor without cluster access, or a consumer of the image: `oci`, because `cosign verify-attestation` finds it from the image reference alone.
3. A cluster that prunes runs: add a durable backend, because annotations disappear with the run.
4. A central store for many clusters: `gcs`, `docdb`, `grafeas` or `archivista`, depending on what the organisation already runs.

The default for the images themselves is separate. `artifacts.oci.storage` takes the same kind of list and defaults to `oci`. The signature of an image goes to the registry unless you change it.

## Mission

Apply what you learned in a real task. The lab runs in its own cluster, so first pause your playground. Nothing in it is lost:

```sh
astrona stop ats-129-playground-010-02
```

Then start the lab:

```sh
astrona run --git ssh://git@github.com/astrona-io/ATS129.git -c sections/section-010/module-02/labs/lab-01
```

The task is on the next page. Solve it on your own first. When you think you are done, send it for grading:

```sh
astrona submit -c sections/section-010/module-02/labs/lab-01
```

When the lab is done, remove it and start your playground again:

```sh
astrona destroy ats-129-lab-010-02
astrona start ats-129-playground-010-02
```

## Common pitfalls

> [!WARNING]
> - **Storing only in annotations on a pruned cluster.** The statement is deleted with the run.
> - **Writing `oci` and expecting a non-image artifact to be attached.** Without an image result, there is no image to attach to.
> - **Writing spaces or wrong separators in the list.** Use commas: `tekton,oci`.
> - **Forgetting where the attestation went.** With `storage.oci.repository` set, look in that repository.
> - **Leaving out keys when you apply the ConfigMap.** `kubectl apply` removes keys that an earlier apply set and the new file omits.
