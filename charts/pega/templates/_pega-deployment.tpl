{{- define  "pega.deployment" -}}
kind: {{ .kind }}
apiVersion: {{ .apiVersion }}
metadata:
  name: {{ .name }}
  namespace: {{ .root.Release.Namespace }}
  labels:
    app: {{ .name }} {{/* This is intentionally always the web name because that's what we call our "app" */}}
    component: Pega
spec:
  # Replicas specify the number of copies for {{ .name }}
  replicas: {{ .node.replicas }}
{{- if (eq .kind "Deployment") }}
  progressDeadlineSeconds: 2147483647
{{- end }}
  selector:
    matchLabels:
      app: {{ .name }}
{{- if .node.deploymentStrategy }}
  strategy:
{{ toYaml .node.deploymentStrategy | indent 4 }}
{{- end }}
  template:
    metadata:
      labels:
        app: {{ .name }}
      annotations:
        config-check: {{ include (print .root.Template.BasePath "/pega-environment-config.yaml") .root | sha256sum }}
    spec:
      volumes:
      # Volume used to mount config files.
      - name: {{ template "pegaVolumeConfig" }}
        configMap:
          # This name will be referred in the volume mounts kind.
          name: {{ .name }}
          # Used to specify permissions on files within the volume.
          defaultMode: 420
      - name: {{ template "pegaVolumeCredentials" }}
        secret:
          # This name will be referred in the volume mounts kind.
          secretName: {{ template "pegaCredentialsSecret" }}
          # Used to specify permissions on files within the volume.
          defaultMode: 420
{{- if .custom }}
{{- if .custom.volumes }}
      # Additional custom volumes
{{ toYaml .custom.volumes | indent 6 }}
{{- end }}
{{- end }}
      initContainers:
{{- range $i, $val := .initContainers }}
{{ include $val $.root | indent 6 }}
{{- end }}
{{- if .custom }}
{{- if .custom.initContainers }}
        # Additional custom init containers
{{ toYaml .custom.initContainers | indent 6 }}
{{- end }}
{{- end }}
      containers:
      # Name of the container
      - name: pega-web-tomcat
        # The pega image, you may use the official pega distribution or you may extend
        # and host it yourself.  See the image documentation for more information.
        image: {{ .root.Values.docker.pega.image }}
        # Pod (app instance) listens on this port
        ports:
        - containerPort: 8080
          name: pega-web-port
{{- if .custom }}
{{- if .custom.ports }}
        # Additional custom ports
{{ toYaml .custom.ports | indent 8 }}
{{- end }}
{{- end }}
        # Specify any of the container environment variables here
        env:
        # Node type of the Pega nodes for {{ .name }}
        - name: NODE_TYPE
          value: {{ .nodeType }}
{{- if .custom }}
{{- if .custom.env }}
        # Additional custom env vars
{{ toYaml .custom.env | indent 8 }}
{{- end }}
{{- end }}
{{ include "pega.jvmconfig" (dict "node" .node) | indent 8 }}
        envFrom:
        - configMapRef:
            name: {{ template "pegaEnvironmentConfig" }}
        resources:
          # Maximum CPU and Memory that the containers for {{ .name }} can use
          limits:
          {{- if .node.cpuLimit }}
            cpu: "{{ .node.cpuLimit }}"
          {{- else }}
            cpu: 2
          {{- end }}
          {{- if .node.memLimit }}
            memory: "{{ .node.memLimit }}"
          {{- else }}
            memory: "8Gi"
          {{- end }}
          # CPU and Memory that the containers for {{ .name }} request
          requests:
          {{- if .node.cpuRequest }}
            cpu: "{{ .node.cpuRequest }}"
          {{- else }}
            cpu: 200m
          {{- end }}
          {{- if .node.memRequest }}
            memory: "{{ .node.memRequest }}"
          {{- else }}
            memory: "6Gi"
          {{- end }}
        volumeMounts:
        # The given mountpath is mapped to volume with the specified name.  The config map files are mounted here.
        - name: {{ template "pegaVolumeConfig" }}
          mountPath: "/opt/pega/config"
{{- if (.node.volumeClaimTemplate) }}
        - name: {{ .name }}
          mountPath: "/opt/pega/streamvol"
{{- end }}
{{- if .custom }}
{{- if .custom.volumeMounts }}
        # Additional custom mounts
{{ toYaml .custom.volumeMounts | indent 8 }}
{{- end }}
{{- end }}
        - name: {{ template "pegaVolumeCredentials" }}
          mountPath: "/opt/pega/secrets"
{{ include "pega.health.probes" .root | indent 8 }}
      # Mentions the restart policy to be followed by the pod.  'Always' means that a new pod will always be created irrespective of type of the failure.
      restartPolicy: Always
      # Amount of time in which container has to gracefully shutdown.
      terminationGracePeriodSeconds: 300
      # Secret which is used to pull the image from the repository.  This secret contains docker login details for the particular user.
      # If the image is in a protected registry, you must specify a secret to access it.
      imagePullSecrets:
      - name: {{ template "pegaRegistrySecret" }}
{{- if (.node.volumeClaimTemplate) }}
  volumeClaimTemplates:
  - metadata:
      name: {{ .name }}
      creationTimestamp:
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: {{ .node.volumeClaimTemplate.resources.requests.storage }}
  serviceName: {{ .name }}
{{- end }}
---
{{- end -}}
