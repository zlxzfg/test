# 使用说明
```
脚本的默认部署一个centos6.8的pxe服务端，默认批量安装的
      客户端也为centos6.8系统。

1、单pxeserver的系统版本和pxeserver正要安装的iso版本不相同时，
   需要从与pxeclient版本相同的系统上面复制一个pxelinux.0 ，放在对应的目录下面
2、这个配置脚在centos6的系统上面开发，其他的版本系统可能有兼容性的问题
3、ks.cfg 一般有一下集中获取方式
      a.手动编写
      b. kickstart工具在图形的界面下面生成
      c. 一台安装好的样机的/root/ 下面的anaconda-ks.cfg
4、脚本默认ks.cfg文件中不包含任何软件包，配置完成后引导的是一个极其精简的系统
5、手动安装依赖的服务httpd，dhcp，xinetd，tftp-server时，用yum安装，编译安装的方式没有测试过
6、外部需要手动插入光驱（虚拟机上光驱需要改为已连接状态，保持开机链接），光驱设备/dev/sr0
```

# 一个redhat i386 5.6的批量部署说明 

```
以下的步奏是配置一个能够批量部署redhat 5.6系统的补充操作（服务端仍然为 centos 6.8）

1、首先使用redhat i386 5,6光盘镜像在本地虚拟机上面安装一次，
   将其中的anaconda-ks.cfg，/usr/****/pxelinux.0,复制出来备用
2、根据上一步anaconda-ks.cfg 中的内容编写ks.cfg，内容大体相同，一些小修改
3、将ks.cfg放在web上面，其链接路径由 tftpboot/pxelinux.cfg/default 
   中指定（tftpboot路径在/etc/xinetd.d/tftp中指定），注意该文件的权限至少为644
4、移除tftpboot中除了pxelinux.cfg/ 目录树之外的所有内容
5、将第一步中的/pxelinux.0放入tftpboot中
6、将redhat i386 5,6的镜像挂载到web上，web的访问路径由ks.cfg文件中的url配置
   指定（也可以通过cp -a的方式将iso中的所有文件拷贝至web上面的指定路径中，
   这样就iso不用挂载到web上面，降低cd/dvd的使用频率，减少损坏率）

通常，上面的操作完成后，外部的pxeclient就可以启动了


Created by xiaofan.
```
