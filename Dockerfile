# setting a tag helps us knowing 
# that everything below is related to it
FROM node:alpine as builder
WORKDIR '/app'
COPY package.json .
RUN npm install
COPY . .
RUN npm run build

# Remember that our build will be at /app/build inside our container!
# Now to the Nginx setup

FROM nginx
# I want to copy something from the builder phase
COPY --from=builder /app/build /usr/share/nginx/html
# As nginx container image already deals wit hthe startup command
# we don't need call a RUN command.