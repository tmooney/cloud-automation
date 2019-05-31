# kiam
This is a work in progress - this branch shows basic configs for getting it running manually on our cluster.  
Also see the [kiam-nodepool branch](https://github.com/uc-cdis/cloud-automation/tree/feat/kiam-nodepool) where I started working on refactoring tf files for deploying nodes for running the servers on.

## General Resources

[uswitch/kiam](https://github.com/uswitch/kiam)

[IAM Access in Kubernetes: Installing kiam in production](https://www.bluematador.com/blog/iam-access-in-kubernetes-installing-kiam-in-production)

[Slack](https://kubernetes.slack.com/messages/CBQLKVABH/convo/CBQLKVABH-1551448927.042700/)

[https://www.youtube.com/watch?time_continue=11&v=vgs3Af_ew3c](https://www.youtube.com/watch?time_continue=11&v=vgs3Af_ew3c)

### General Steps
Note that these are approximate - I no longer have access to cdistest so this is from my old notes 
1. create the kiam-server role in AWS - see the Roles/Policies section below. Also create (or find) the role you want a pod to assume and configure it (again see Roles section below).
2. Create TLS certs for kiam server and agent communication. Although I started some work using OpenSSL in kube-setup-secrets of this branch, I punted that (OpenSSL is nuts) and ended up just generating Certs with the tool they suggest here: https://github.com/uswitch/kiam/blob/master/docs/TLS.md
I then made the secrets (naming must match b/c we use them in our deployments)
  ```
  kubectl create secret generic kiam-server-tls -n kube-system --from-file=ca.pem --from-file=kiam-server.crt --from-file=kiam-server.key
  kubectl create secret generic kiam-agent-tls -n kube-system --from-file=ca.pem --from-file=kiam-agent.crt --from-file=kiam-agent.key
  ```
3. Update the namespace you want to deploy pods to where IAM is managed by kiam:
```
kind: Namespace
apiVersion: v1
metadata:
  name: <your namespace> 
  annotations:
    # this is the important bit - which iam roles are allowed in namespace
    iam.amazonaws.com/permitted: ".*" 
```
4. Setup kaim server stuff/rbac - gives server permissions it needs to work. Deploy the kiam server (it'll be launched on all nodes - this is obviously something you'll want to change later)
```
kubectl apply -f kiam-server-rbac.yaml
kubectl apply -f kiam-server-service.yaml
```
Check server logs to make sure that worked.

5. For testing taint a node for deploying an agetnt onto, e.g. `kubectl taint nodes ip-172-24-68-185.ec2.internal kiam=kiam:NoSchedule`. We do this b/c the agent modifies the iptables on the node to redirect metadata requests to the agent, which can break your jobs/services that require this.
Make sure your agent's yaml file is set to be deployed on that tainted node

6. Deploy agent onto tainted node
```
kubectl apply -f kiam-agent-daemonset.yaml
```
Check agent logs to make sure it's working.

7. Deploy a test node onto the tainted node to make sure it works. I made a modified `indexd-deployment.yaml` in this directory which shows how it would be configured to use an IAM role. I think you should be able to check the agent and server logs to see that they realize a pod has been launched with iam annotations.

Also, to test that it's working, you can exec into the container and do `aws sts get-caller-identity` if aws cli is installed (or just make a request for the resource the role has access to), or do a `wget http://169.254.169.254/latest/meta-data/`. It can be helpful to check the server and agent logs for debugging.

## Setup Roles/Policies
The general setup is that our instances have a role they assume, we allow that role to assume the kiam-server role, then we allow the kiam-server role to assume the roles we assign to pods.
I refer to the role assumed by the ec2 instance as eks_worker, the kiam-server role as kiam-server, and the example role that our pod would assume as bucket_reader_tedtest1-databucket-gen3 (can just read a bucket).

Helpful aws cli commands to get role info and update policies - this type of stuff will obviously need to be automated/put into terraform
```
# Get info calls
#

# get role information INCLUDING assume role policy document (useful for all roles)
aws iam get-role --role-name rolename

# list inline role policies (useful for eks_worker)
aws iam list-role-policies --role-name rolename
# get inline policy
aws iam get-role-policy --role-name rolename --policy-name policyname

# list attached policy arns (kiam-server)
aws iam list-attached-role-policies --role-name rolename
# get inline policy document
aws iam get-policy-version --policy-arn arn --version-id v1

#
# Update calls
#

# add/update an inline role policy (use on eks_worker to act like kiam-server)
aws iam put-role-policy --role-name rolename --policy-name policyname --policy-document file://docpath

# update assume role policy (use on kiam-server to allow eks_worker to act like it - also on bucket_reader to allow kiam-server to act like it)
aws iam update-assume-role-policy --role-name rolename --policy-document file://docpath
```
## eks_worker role
This is already created and assumed by nodes.
### assume role policy document

"ec2 instances can act like me"
```
    {
        "Version": "2012-10-17", 
        "Statement": [
            {
                "Action": "sts:AssumeRole", 
                "Effect": "Allow", 
                "Principal": {
                    "Service": "ec2.amazonaws.com"
                }
            }
        ]
    }
```
### inline policy
You need to attach this policy to the eks_worker.
"I can act like kiam-server (if it lets me)"
```
    {
        "Version": "2012-10-17", 
        "Statement": [
            {
                "Action": [
                    "sts:AssumeRole"
                ], 
                "Resource": "arn:aws:iam::<aws_acct_id>:role/kiam-server", 
                "Effect": "Allow"
            }
        ]
    }
```
## kiam-server role
You need to create this role yourself (or use the one I made if it's still around)
### assume role policy document
"eks_worker can act like me"
This needs to be updated to allow the eks_worker to act like it. This is the new assumer role policy document:
```
    {
        "Version": "2012-10-17", 
        "Statement": [
            {
                "Action": "sts:AssumeRole", 
                "Principal": {
                    "AWS": "arn:aws:iam::<aws_acct_id>:role/eks_devplanetv1_workers_role"
                }, 
                "Effect": "Allow", 
                "Sid": ""
            }
        ]
    }
```
### attached policy document
"I can act like anyone who lets me (e.g. a role with s3 bucket read permissions attached to a pod...)"
```
    {
        "Version": "2012-10-17", 
        "Statement": [
            {
                "Action": [
                    "sts:AssumeRole"
                ], 
                "Resource": "*", 
                "Effect": "Allow"
            }
        ]
    }
```
## bucket_reader_tedtest1-databucket-gen3
This is the role you want pods to assume which will be used by your service.
### assume role policy document
This needs to be updated so that our kiam-server role can act like it. This is the new policy document:

"kiam-server can act like me"
```
    {
        "Version": "2012-10-17", 
        "Statement": [
            {
                "Action": "sts:AssumeRole", 
                "Principal": {
                    "Service": "ec2.amazonaws.com"
                }, 
                "Effect": "Allow", 
                "Sid": ""
            },
    				{
                "Action": "sts:AssumeRole", 
                "Principal": {
                    "AWS": "arn:aws:iam::<aws_acct_id>:role/kiam-server"
                }, 
                "Effect": "Allow", 
                "Sid": ""
            }
        ]
    }
```