# 功能编排（P2/P4）

后续创建 RefeedFeature 和 AutoSwitchFeature。重喂确认中文状态后才替换选区；`RecoverLast()` 原样插入缓存，不执行撤销。自动切换尊重手动选择，重喂期间两项功能互斥。
