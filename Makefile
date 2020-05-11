all: create

patch:
	oc new-project sso
	oc project sso
	oc patch namespace sso -p '{"metadata": {"annotations": {"openshift.io/node-selector": "region=compute"}}}'

create: 
	oc create -f keycloak-https-mutual-tls.yml

delete:
	oc delete namespace sso

recreate: delete create
	
