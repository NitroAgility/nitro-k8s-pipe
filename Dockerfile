FROM ubuntu:18.04
COPY . .
RUN bash ./nitro-k8s-pipe.sh -v
CMD kubectl get pods -n dev