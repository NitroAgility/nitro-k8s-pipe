FROM ubuntu:18.04
ENV PIPE_AWS_ACCESS_KEY=$aws_access_key
ENV PIPE_AWS_SECRET_ACCESS_KEY=$aws_secret_access_key

COPY . .
RUN bash ./nitro-k8s-pipe.sh -v
CMD kubectl get pods -n dev