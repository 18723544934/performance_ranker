# PerfTop - iOS 性能排行榜应用

一款面向数码爱好者的 iOS 性能排行榜应用，提供电脑与移动端 CPU/GPU 的详尽性能排行、多维度筛选对比、天梯图可视化展示。

## 项目结构

```
PerfTop/
├── PerfTop/
│   ├── Models/                 # 数据模型
│   │   ├── Hardware.swift      # 硬件相关模型
│   │   └── Favorite.swift     # 收藏和历史模型
│   ├── Network/               # 网络层
│   │   └── APIClient.swift   # API 客户端
│   ├── ViewModels/            # 视图模型
│   │   ├── HardwareListViewModel.swift
│   │   ├── HardwareDetailViewModel.swift
│   │   ├── CompareViewModel.swift
│   │   └── CompareManager.swift
│   ├── Views/                 # 视图
│   │   ├── Ranking/           # 排行榜视图
│   │   ├── Detail/           # 详情视图
│   │   ├── Compare/          # 对比视图
│   │   ├── Ladder/          # 天梯图视图
│   │   ├── Favorites/         # 收藏视图
│   │   └── Settings/        # 设置视图
│   ├── Services/              # 服务层
│   │   └── DatabaseService.swift  # 数据库服务
│   ├── Utils/                # 工具类
│   └── PerfTopApp.swift     # 应用入口
├── PerfTopTests/            # 单元测试
├── PerfTopUITests/         # UI 测试
└── Package.swift           # 依赖管理
```

## 核心功能

### 1. 排行榜
- 四类硬件切换：PC CPU / PC GPU / Mobile CPU / Mobile GPU
- 多维度排序：综合、单核、多核、游戏、能效
- 实时搜索和筛选
- 下拉刷新和分页加载

### 2. 详情页
- 完整规格参数展示
- 多基准跑分卡片
- 性能雷达图可视化
- 收藏和对比功能入口

### 3. 对比功能
- 最多支持 5 款硬件对比
- 规格参数对比表
- 跑分柱状图对比
- 高亮最佳/最差项

### 4. 天梯图
- 横向柱状图展示性能排名
- 支持缩放和平移
- 按品牌颜色区分
- 点击跳转详情

### 5. 收藏与历史
- 收藏硬件型号
- 自动记录浏览历史
- 分组管理收藏

### 6. 设置
- 数据更新策略
- 缓存管理
- 外观主题切换
- 关于和反馈

## 技术栈

- **语言**: Swift 5.9+
- **UI 框架**: SwiftUI
- **架构**: MVVM + Coordinator
- **响应式编程**: Combine
- **持久化**: GRDB (SQLite)
- **网络**: URLSession
- **图表**: Charts (DGCharts)
- **图片加载**: Kingfisher
- **依赖管理**: Swift Package Manager

## 数据模型

### Hardware
```swift
struct Hardware {
    let id: Int
    let name: String
    let brand: String
    let category: Category
    let architecture: String
    let launchDate: Date?
    let specifications: Specs
    let benchmarks: [Benchmark]
    let overallScore: Double
    let price: PriceInfo?
}
```

### Category
- `pcCPU`: 电脑 CPU
- `pcGPU`: 电脑 GPU
- `mobileCPU`: 手机 CPU
- `mobileGPU`: 手机 GPU

## API 设计

### 基础 URL
```
https://api.perftop.example.com/v1
```

### 主要端点
- `GET /hardwares` - 获取排行列表
- `GET /hardwares/:id` - 获取型号详情
- `GET /hardwares/compare?ids=1,2,3` - 获取对比数据
- `GET /hardwares/search?q=snapdragon` - 搜索
- `GET /meta/filters?category=pc_gpu` - 获取筛选选项
- `GET /hardwares/export/all` - 全量数据导出

## 本地存储

使用 GRDB (SQLite) 进行本地数据存储：
- `hardware` 表：硬件信息
- `favorite` 表：收藏数据
- `history` 表：浏览历史

## 离线支持

- 核心排行数据本地缓存
- 无网络时仍可查看缓存数据
- 支持手动刷新和后台更新
- 缓存清理功能

## 开发环境

### 最低要求
- Xcode 15.0+
- iOS 15.0+
- Swift 5.9+

### 安装依赖
项目使用 Swift Package Manager，依赖会自动安装。

## 测试

### 单元测试
- ViewModel 逻辑测试
- 数据解析测试
- 数据库操作测试

### UI 测试
- 核心流程测试
- 横竖屏适配测试
- 分屏模式测试

## 发布计划

### 阶段一：MVP（4 周）
- PC CPU 排行基础 API
- 排行首页、详情页、搜索
- 本地缓存与离线浏览

### 阶段二：核心完善（4 周）
- PC GPU、Mobile CPU/GPU 数据与 UI
- 对比功能
- 天梯图视图
- 收藏与历史

### 阶段三：体验优化（3 周）
- 筛选面板
- 自定义权重
- 图表美化、动画
- 多语言支持

### 阶段四：测试与上架（2 周）
- 全面测试、性能调优
- TestFlight 内测
- App Store 提交

## 注意事项

### 数据来源合规
- 遵守网站 robots.txt 及使用条款
- 优先使用官方公开 API
- 用户界面展示数据来源标签
- 商业使用需获取授权

### 性能优化
- 列表滑动 60fps
- 详情页加载 ≤ 1s
- 对比计算 ≤ 0.5s
- 虚拟化渲染天梯图

## 许可证
本项目仅供学习参考使用。
