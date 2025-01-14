{{- define "pega.openshift.ingress" -}}
# Route to be used for {{ .name }}
kind: Route
apiVersion: route.openshift.io/v1
metadata:
  name: {{ .name }}
  annotations:
    # When a route has multiple endpoints, HAProxy distributes requests to the route among the endpoints based on the selected load-balancing strategy. (roundrobin/leastconn/source)
    # roundrobin: Each endpoint is used in turn, according to its weight.
    # leastconn: The endpoint with the lowest number of connections receives the request.
    # source: The source IP address is hashed and divided by the total weight of the running servers to designate which server will receive the request.
    haproxy.router.openshift.io/balance: roundrobin
spec:
  # Host on which you can reach mentioned service.
  host: {{ .node.domain }}
  to:
    kind: Service
    # Name of the service associated with the route
    name: {{ .name }}
  tls:
    # Edge-terminated routes can specify an insecureEdgeTerminationPolicy that enables traffic on insecure schemes (HTTP) to be disabled, allowed or redirected.  (None/Allow/Redirect/EMPTY_VALUE)
    insecureEdgeTerminationPolicy: Redirect
    termination: edge
{{- end }}
