## Dev Container

The SOGo dev container will deploy a complete environnement to work and test with SOGo

This environnement contains:
- a mariadb database
- an imap server (dovecot) and a smtp server (postfix)
- a ldap server for the user source
- an Apache server
- The SOGo instance

## How to use the devcontainer

Simply clone the source code of the SOGo repo and open id with Visual Code Studio. If this is not already the case, you will need the [Dev Container Extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers). Then, simply execute the command "New Dev COntainer" and VCS will start building it.


When it's all build, go to http://127.0.0.1/SOGo. You have 3 users to login with:
`sogo-tests1`, `sogo-tests2`, `sogo-tests3` with all the same password `sogo`

You can only send mail and receive mail among those three users.

**If you have troubles, you may need to build sogo once, see the next section for that.**

## How to work on SOGo


### To modify the source and build

After modifyng the source in VCS, in your container's terminalthere is a command tool `devenv` with following options for building:
```
-b, --build		        Build sogo app
-ba, --build-all	    Clean, build sogo and sope
-br, --build-resources	Build only sogo JS/CSS resources
```

To build sogo simplye does
```shell
sudo devenv -b
```
- The options -br will only build the front
- The options -ba will also build [SOPE](https://github.com/Alinto/sope) (low-level of SOGo, needs to be build before SOGo)


### To use the debugger

Inside the sogo container there is a tool to launch SOGo with the [debugger gdb](https://sourceware.org/gdb/).

Use one of the following command:

```shell
sudo devenv -d
sudo devenv --debug
```


### To change sogo.conf

The sogo.conf is linked to the one here [.devcontainer/conf/sogo/sogo.conf](conf/sogo/sogo.conf)

Modify it as you wish then you need to restart the sogo service inside the container:
```shell
service sogod restart
```

### To modify SOPE

Sometimes, you may have to change SOPE source code. In order to do that:
- First, clone the SOPE repo locally.
- Uncomment line 101 of the docker-compose.yml file and put the correct path to your SOPE folder. It should end with 'sope' like this: `/home/myuser/github/sope`
- Then, you have to rebuild your devcontainer.
- Now you can modify the source of SOPE and build it by going inside the sogo_dev container and do.
```shell
sudo devenv -ba
```