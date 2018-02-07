# UBports boot

UBports initrd (upstart)

#### Build

```
mka ubports-boot
```

#### Initrd debugging:

```
sudo fastboot boot ubports-boot.img -c break=[level]
```

Levels

* modules
* premount
* mount
* mountroot
* bottom

example:

```
sudo fastboot boot ubports-boot.img -c break=premount
```

And use telnet to login:

```
telnet 192.168.2.15
```
