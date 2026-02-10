FROM node:lts

WORKDIR /app

# only copy the dependencies file first to make sure the step is only
# ran if either of these files explicitly change.
COPY package.json yarn.lock ./

RUN yarn install --ignore-scripts

COPY . .

CMD ["npm", "run", "dev"]
