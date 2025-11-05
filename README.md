## 描述
这是一个中兴ZTE-E8820S自用精简固件仓库，源码采用24.10版本或lede，内存布局是hc5962/B70，**请确认你的内存布局再刷，不要下载下来就往里面刷**

**官方源无硬件nat支持，只能软件跑600Mbps ~ 700Mbps**，若你不是千兆则不需要考虑这个，如果你真的需要使用，请改用[lede](https://github.com/coolsnowwolf/lede), release里有两个版本，自取选用

mt7621全系版本有奇怪的重启bug，请见[#issues/19164](https://github.com/openwrt/openwrt/issues/19164)

**但openwrt-23.05甚至老毛子或者immortalwrt，我也遇到过很多次断电后重启以后丢wifi的情况，感觉是openwrt固件写的有问题**

## 自行编译
若你不想使用我预先编译的包，可以clone此仓库，使用github action的runner编译

或者直接运行仓库下的build.sh脚本即可

## 固件软件包
配置为
- zerotier
- usb
- mt76xx wifi
- passwall (只有xray)
- eip93 (硬件加速）
- kmod-cryptodev (Cryptographic Hardware Accelerators in user level)
- kmod-crypto-* (frequenctly used crypto kmod)

## 跑分（单位为MiB/s)

### 跑分
参数如下
> openssl speed -evp <algorithm>

| Block Size (bytes) | ChaCha20 |   md5 | ChaCha20-Poly1305 | AES-128-CTR | AES-128-CTR(硬件加速) |
| -----------------: | -------: | ----: | ----------------: | ----------: |------------:|
|                 16 |    14.53 |  1.72 |              9.56 |        9.54 |       39.04 |
|                 64 |    23.42 |  6.17 |             16.10 |       11.57 |       52.04 |
|                256 |    27.15 | 20.45 |             18.72 |       12.11 |       91.35 |
|               1024 |    27.75 | 45.70 |             19.55 |       12.30 |       16.80 |
|               8192 |    28.53 | 72.90 |             19.77 |       12.32 |       46.03 |
|              16384 |    28.58 | 75.44 |             19.83 |       12.34 |       54.14 |

由于mt7621只有ctr的加速，会回落chacha20-poly, 若使用reality等tls类协议，单线程理论上限就是19.83MiB/s上下浮动

若跑专线，建议使用纯ChaCha20或者vless-encryption，否则用reality

## 预览
以下为均为只开zerotier+passwall分流的情况

### 23.05版本

占用20M是因为我更新了xray版本

<img width="1444" height="877" alt="image" src="https://github.com/user-attachments/assets/7a80c0c8-303b-49cf-a001-952f426b76ee" />

### 24.10版本
<img width="1375" height="887" alt="image" src="https://github.com/user-attachments/assets/d9ace000-de79-4be8-bfc4-9bdbe955e5c8" />


