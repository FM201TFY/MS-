# MS-perl-build random Polymer cell
使用MS内置的模块进行复制粘贴
第一个脚本是在build里面进行，主要的工作就是 copy script。唯一的亮点就是用了个循环可以控制自己想建的链数.....至于聚合度，MS仅能支持10-1000，全原子。
第二个脚本是在AC模块里面进行copy script。也是使用for循环进行加链，需要改力场参数的可以自行查找MS官方的使用手册进行修改。个人建议：一定要有坚实的基础再去选择力场，不然你的Partial Charge和atom type等会要了老命....
