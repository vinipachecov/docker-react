# Building a React app and serving with Nginx on AWS using Docker(Elastic Beanstalk)

The idea of using Docker is to attempt to make the deploy simple, although it is possible to make all these steps without docker.

Sections: 
 - [Create the react-app](#create-the-react-app)
- [Create a new repo on your github profile](#create-new-repo-on-your-github-profile)
- [Create a Dockerfile](#create-a-dockerfile)
- [Create travis configuration](#create-travis-configuration): 
  - [Pre-install](#pre-install)
  - [Script (Tests)](#script)
  - [Deploy](#deploy)
  - [Creating a IAM politic for deploying in Elastic Beanstalk](#creating-a-IAM-politic-for-deploying-in-Elastic-Beanstalk)
  -[Travis setup and AWS Beanstalk config sync](#travis-setup-and-aws-beanstalk-config-sync)
- [Actually deploying](#actually-deploying)

This repository is sonely to give basic instuctions on creating and deploying a react-app to Elastic Beanstalk using docker and Travis CI.

* Remember that to use Travis CI you need to have your code public, if you can't try other CI/CD solution like Circle/CI, Bitbucket-Pipelines etc...

## Create the react-app

Ok so first create a react app with create-react-app cli:

```
create-react-app docker-react
```

## Create a new repo on your github profile

Signin in your github profile and create a public repository, I'll assume here that the name is docker-react for the sake of simplicity.

## Create a Dockerfile

Using your favorite code editor, open the folder of your react-app and create a file "Dockerfile". Copy this content so later I'll explain:

```yml
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
EXPOSE 80
# I want to copy something from the builder phase
COPY --from=builder /app/build /usr/share/nginx/html
# As nginx container image already deals wit hthe startup command
# we don't need call a RUN command.
```

Ok so alot of code in here. 

- FROM is the tag for the docker image "node:alpine" where alpine is usually a good indicator that it is a very small image in the docker world. Remember the alias "as builder".
- WORKDIR is where your app will be installed in the docker container
- COPY is to copy files, which in this case happens twice to avoid sending node_modules
- RUN will run our react app build.

The second stage:

- FROM nginx: is related to the nginx image
- EXPOSE is a tag for Elastic Beanstalk to expose port 80 where our traffic will happen
- COPY will send the files to from stage builder (alias) into the specific folder.


Well that is our code so far, the react-app boilerplate and the Dockerfile setup.


## Create travis configuration

Travis will be our CI/CD helper in this tutorial.
If you don't have a travis account, go in there and sign up. After sign up, signin into your new account and link to github to have access to your repositories. 
Go to your profile picture (usually in the top right corner of the screen) and click on "settings".
Select your docker-react repository. Now to the config file, create a file inside your folder with the name of ".travis.yml"

```yml
sudo: required
services:
  - docker

# use a tag to the container so we can call it later
before_install:
  - docker build -t vinipachecov/docker-react -f Dockerfile.dev .

# run when our test suite be executed
script:
  - docker run vinipachecov/docker-react npm run ci-test -- --coverage


deploy:
  provider: elasticbeanstalk
  region: "us-east-1"
  name: "docker-react"
  env: "DockerReact-env"
  # bucket configurations
  bucket_name: "elasticbeanstalk-us-east-1-466903733458"
  bucket_path: "docker-react"  
  on:
    branch: master
  access_key_id: $AWS_ACCESS_ID
  secret_access_key:
    secure: $AWS_ACCESS_SECRET    
```

Well this file is a little bit bigger, we can split it into three parts:

1. Install
2. Run
3. Deploy

### Install
```yml
sudo: required
services:
  - docker
```

Sudo is a keyword for super user permissions which is required for deploying and installing.
Services is the applications we will require here, which in this case is Docker.


### Pre-install
```yml
before_install:
  - docker build -t vinipachecov/docker-react -f Dockerfile.dev .
```
Before install is a stage so we can test stuff before deploying. Here I created a Dockerfile.dev just for testing. Watchout for the tag after the -t param: "vinipachecov/docker-react". vinipachecov here is the name of the user I've used and docker-react the name of the container so I could use it later.

```yml
FROM node:alpine

WORKDIR '/app'

COPY package.json .
RUN npm install
COPY . .
CMD ["npm","run","start"]
```
### Script (Tests)
```yml
script:
  - docker run vinipachecov/docker-react npm run ci-test -- --coverage
```

Well here we have a the actual test using the previous tag "vinipachecov/docker-react".
THe ci-test command is in the package.json file which is :
```
"ci-test": "CI=true react-scripts test"
```
The use of CI=true is because the testing framework jest doesn't quit after a test run, because it opens a dialog for further testing capabilities. To quit testing we have to use this environment variable and also use the -- --coverage so it will quit after the test run.

### Deploy

The deploy configuration will required a few more steps:

1. Sign in (or sign up and sign in) to your AWS Account
2. Create a Elastic Beanstalk environment
3. Create a IAM politic for deploying in Elastic Beanstalk.
4. Create the app inside of it.

Number one depends on you, so create the account and sign in. Now, the second step is to go into services and find Elastic Beanstalk and click to start using it. It will ask your for an app name and a platform.
app name is up to you but I'll name it docker-react for the sake of simplicity and choose the platform to Docker. After this setup it will start to deploy an instance of Elastic Beanstalk and create an environment for this app. 
It will also create an AWS S3 Bucket for serving static files with probably the a name with like this "elasticbeanstalk-137837483".
After the setup you will have a URL for your app which you will be able to see your new instance running.

### Creating a IAM politic for deploying in Elastic Beanstalk

In this third step we will go into services in our AWS dashboard and click on IAM(Identity and Access Management). In the left side bar we have Users, and after clicking on it we have a Create new User button.
Choose a name for your new profile, I'll choose elasticBeanstalk and checkup the first tag which should say you will create an ID Access key and a Secret KEY for the AWS API.

Now choose to attach policies instead of adding the user into a group, then type in the search bar and check the checkbox which show Provides full access to AWS Elastic Beanstalk and continue.
If you need to use any tags this next step is usefull for setting responsibilities or who is deploying and more. Click on next and you will have a new Access ID Key and a Secret key. 
Do NOT close this browser tab. 

### Travis setup and AWS Beanstalk config sync
Open a new tab and go back to the Travis. Go into your travis repository dashboard and on the top right corner there is a button "more options" which have "settings" option, click on it. 
Now we are going to create to environment variable into Travis so it will be able to deploy into AWS Elastic Beanstalk diretcly for us.

I'll create two keys, one for each key value from my new IAM user from the other tab. 

* AWS_ACCESS_ID: for the AWS id key
* AWS_ACCESS_SECRET: for the AWS Secret key

Paste the values for each of them and add them. Great, now we have variable which we have access to deploy into our Elastic Beanstalk enviroment on AWS directly from Travis!

Let's check our .travis.yml file again and see our last part of the config:

```yml
deploy:
  provider: elasticbeanstalk
  region: "us-east-1"
  name: "docker-react"
  env: "DockerReact-env"
  # bucket configurations
  bucket_name: "elasticbeanstalk-us-east-1-466903733458"
  bucket_path: "docker-react"  
  on:
    branch: master
  access_key_id: $AWS_ACCESS_ID
  secret_access_key:
    secure: $AWS_ACCESS_SECRET
```

Ok let's go tag by tag, 

- deploy: 

is a section of the travis ci/cd.
- provider: elasticbeanstalk
 Is the service we are about to use, there are tons of this registered. In our particular case we are using elastic beanstalk.
For more check on https://docs.travis-ci.com/user/deployment
- region: "us-east-1"
Region of our docke-react elastic beanstalk instance. In the URL of your the last part ends with "elasticbeanstalk.com.". The part fore this will be your region, which is where the app is hosted, in my case is us-east-1.
- name: "docker-react"
Name of the aws elastic beanstalk app.
- env: "DockerReact-env"
Name of the environment created after creating the elastic beanstalk app.  
- bucket_name: "elasticbeanstalk-us-east-1-466903733458"
As I said, Elastic beanstalk creates a S3 bucket. go into the S3 section and find a bucket which has "elasticbeanstalk-YOUR-REGION-HERE%%%%" pattern.-
  bucket_path: "docker-react"  
Use the same name of your app so it will be easier to maintain this bucket. This is the name of the folder with your static assets.
  - on:
    branch: master
Which branch of your github repo you are about to be watching changes on.
-   access_key_id: $AWS_ACCESS_ID
-   secret_access_key:
      secure: $AWS_ACCESS_SECRET

Now is time to use our environment variables from Travis and set them here into both access_key_id and secret_access_key. The only difference is that secret requires the secure tag.


### Actually deploying

Now you will have to add the files, do a commit and push this commit into the repo. It will run through all the pipeline we've setup and in the end will be served into Elastic Beanstalk using Nginx to serve the static files.
To do it you can change App.js p tag content for something you like and push into to your repo:

```
git add .
```

```
git commit -m 'deploying to AWS'
```

```
git push origin master 
```

Check your repo in Travis dashboard and AWS Elastic Beanstalk app to check if everything went successful. Finally open the url of your app in AWS to see the deployed app.

Hope you guys enjoyed! Doubts and suggestions are welcome :D



