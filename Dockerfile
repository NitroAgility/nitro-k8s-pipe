FROM ubuntu:18.04
# Arguments
ARG PIPE_AWS_ACCESS_KEY=
ARG PIPE_AWS_SECRET_ACCESS_KEY=

# Environment variables
ENV PIPE_AWS_ACCESS_KEY $PIPE_AWS_ACCESS_KEY
ENV PIPE_AWS_SECRET_ACCESS_KEY $PIPE_AWS_SECRET_ACCESS_KEY

# Copy files and run the configuration
COPY . .
RUN bash ./nitro-k8s-pipe.sh -v

# Run the check command
CMD kubectl get pods -n dev