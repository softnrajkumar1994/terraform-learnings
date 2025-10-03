# Start from AWS base image for Java 17
FROM public.ecr.aws/lambda/java:17

# Copy compiled JAR into the image
# (assumes Maven/Gradle builds `target/hello-world-lambda.jar`)
COPY target/hello-world-lambda-1.0.0.jar ${LAMBDA_TASK_ROOT}/app.jar

# Set the CMD to your handler
CMD ["example.HelloWorldHandler::handleRequest"]
