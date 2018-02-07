# Halium-boot

bootimg generator for Halium ports 

#### Build

```
mka halium-boot
```

#### Initrd debugging:

```
sudo fastboot boot halium-boot.img -c break=[level]
```

Levels

* modules
* premount
* mount
* mountroot
* bottom

example:

```
sudo fastboot boot halium-boot.img -c break=premount
```

And use telnet to login:

```
telnet 192.168.2.15
```
