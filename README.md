# MediaWikiInstance

This repository contains a Docker Compose configuration for running a MediaWiki
instance with a MySQL database, along with the [Loftia] skin.

## Prerequisites

 - Docker and Docker Compose, or compatible such as Podman and Podman Compose.
 - Git (with submodules) to clone the repository and its submodules.

## How to Use This Repository

 1. Clone this repository to your local machine:
    ```bash
    git clone https://github.com/PrestonHager/MediaWikiInstance.git
    cd MediaWikiInstance
    git submodule update --init --recursive
     ```
 2. Start the MediaWiki and MySQL containers using Docker Compose. The `-d` flag
    starts the containers in a daemonized mode.
    ```bash
     docker compose up -d
     ```
     Note that to run docker you may need to use `sudo` or add your user to the
     docker group.
 3. Run the installation script to set up MediaWiki. You can do this by
    executing the following command:
    ```bash
    ./setup_wiki.sh --wiki-name=Wiki --admin-user=Admin --admin-password=password
    ```
 4. Open your web browser and navigate to `http://localhost:8080` to access the
    MediaWiki installation page. If you are using a remote server, replace
    `localhost` with the server's IP address or domain name and ensure that the
    proper ports are open.
 5. To stop the containers, run:
 
    ```bash
     docker-compose down
     ```

[0]: https://github.com/PrestonHager/LoftiaMediaWikiSkin

