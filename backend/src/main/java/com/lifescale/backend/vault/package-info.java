/**
 * Vault 多端同步模块：Obsidian 风格的路径中心文件同步。
 * 同步单位 = vault 相对路径 + 内容 hash；.md 文件保持纯净，元数据落库 + CAS。
 * 包含文件索引、版本历史、冲突记录、内容寻址存储、三方合并与同步服务。
 */
package com.lifescale.backend.vault;
