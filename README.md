# ESP32-S3 墨水屏天气终端

基于 ESP32-S3 + 7.5寸 Waveshare E-Paper 的低功耗信息显示终端，展示天气、待办事项和日程。

## 硬件

| 元件 | 型号/说明 |
|------|-----------|
| 主控 | ESP32-S3 (8MB PSRAM, octal SPI) |
| 屏幕 | 7.5" Waveshare E-Paper B74 v2 (800×480) |
| 电池 | LiPo (GPIO1 ADC 检测电压) |
| 按键 | GPIO2 (唤醒) / GPIO3 (翻页) |

## 引脚连接

| 功能 | GPIO | 说明 |
|------|------|------|
| SPI CLK | GPIO7 | |
| SPI MOSI | GPIO9 | |
| E-Paper CS | GPIO44 | |
| E-Paper DC | GPIO10 | |
| E-Paper Reset | GPIO38 | |
| E-Paper Busy | GPIO4 | inverted |
| 电池 ADC | GPIO1 | 12dB 衰减 |
| 电池 Enable | GPIO6 | 输出控制 |
| 按键（唤醒） | GPIO2 | inverted, pullup |
| 按键（翻页） | GPIO3 | inverted, pullup |

## 功能特性

- **天气显示**：天气状况 + 温度（来自 HA 天气实体）
- **待办事项**：重要待办列表（从 HA sensor 读取）
- **日程安排**：近48小时日程（从 HA sensor 读取）
- **自动刷新**：每天 7:00 / 12:00 / 18:00~22:00 定时更新
- **低功耗**：深度睡眠 + 每5分钟唤醒检测，电池供电可持续数周
- **USB 供电模式**：检测到 USB 通电时持续显示，每分钟自动刷新

## 配置

### 1. ESPHome 配置

复制 `esp32-epaper.yaml.example` 为 `esp32-epaper.yaml`，修改以下 Secrets：

```yaml
wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password

api:
  encryption:
    key: !secret api_encryption_key

ota:
  password: !secret ota_password
```

### 2. 编译烧录

```bash
# 方式一：Docker（推荐）
docker exec esphome esphome run /config/esp32-epaper.yaml

# 方式二：本地 ESPHome
esphome run esp32-epaper.yaml
```

### 3. Home Assistant 实体配置

本设备依赖以下 HA 实体，**天气实体**可直接使用现有实体，**待办和日程传感器**需通过模板创建：

#### 3.1 天气实体（已有则跳过）

使用和风天气或其他天气集成，实体 ID 格式：`weather.xiaomi_weather`（替换为你的实际实体）。

#### 3.2 待办列表传感器

在 `configuration.yaml` 中添加 Template Sensor：

```yaml
template:
  - sensor:
      - name: "ESP 待办列表"
        unique_id: esp_todo_list
        state: >
          {%- set todos = state_attr('calendar.home', 'description') or '' -%}
          {%- set tasks = namespace(items=[]) -%}
          {%- for event in states.calendar.home.attributes.events -%}
            {%- if '待办' in event.summary -%}
              {%- set tasks.items = tasks.items + [event.summary ~ ' @' ~ event.start] -%}
            {%- endif -%}
          {%- endfor -%}
          {{ tasks.items | join('|') }}
```

或使用简单版本（手动维护）：

```yaml
template:
  - sensor:
      - name: "ESP 待办列表"
        unique_id: esp_todo_list
        state: >
          {%- set items = [
            '买菜',
            '复习英语',
            '钢琴课 15:00',
            '打卡健身'
          ] -%}
          {{ items | join('|') }}
```

#### 3.3 48小时日程传感器

```yaml
template:
  - sensor:
      - name: "ESP 48小时日程"
        unique_id: esp_48_schedule
        state: >
          {%- set now = now() -%}
          {%- set later = now() + timedelta(hours=48) -%}
          {%- set events = namespace(items=[]) -%}
          {%- for cal in states.calendar -%}
            {%- for event in (cal.attributes.events or []) -%}
              {%- set start = as_timestamp(strptime(cal.entity_id, 'calendar.%')) -%}
              {%- if start and start >= as_timestamp(now) and start <= as_timestamp(later) -%}
                {%- set h = as_timestamp(strptime(cal.entity_id, 'calendar.%')) -%}
                {%- set dt = as_datetime(cal.entity_id).replace(tzinfo=None) -%}
                {%- set events.items = events.items + [dt.strftime('%H:%M') ~ ' ' ~ event.summary] -%}
              {%- endif -%}
            {%- endfor -%}
          {%- endfor -%}
          {{ events.items | join('|') }}
```

> **提示**：模板语法复杂，建议先在 HA开发者工具 → 模板 中调试，确认输出格式为 `时间 事件|时间 事件|...`（用 `|` 分隔）。

### 4. 修改数据源

编辑 `esp32-epaper.yaml` 中的 `text_sensor` 段，替换为你的实际实体 ID：

```yaml
text_sensor:
  - platform: homeassistant
    entity_id: weather.your_weather_entity   # 替换为你的天气实体
    id: my_weather

  - platform: homeassistant
    entity_id: weather.your_weather_entity    # 替换为你的天气实体
    id: weather_temp
    attribute: "temperature"

  - platform: homeassistant
    entity_id: sensor.esp_todo_list          # 替换为你的待办传感器
    id: todo_list

  - platform: homeassistant
    entity_id: sensor.esp_48_schedule        # 替换为你的日程传感器
    id: schedule_48h
```

## 电源管理

设备支持两种供电模式，**自动检测切换**：

| 模式 | 条件 | 行为 |
|------|------|------|
| USB 供电 | 电池电压 > 4.1V | 持续显示，每分钟刷新，阻止深度睡眠 |
| 电池供电 | 电池电压 ≤ 4.1V | 每5分钟唤醒检测，`needs_update` 标志为 true 时刷新屏幕 |

## 定时刷新逻辑

```
定时触发（7:00/12:00/18~22:00）
    ↓ 设置 needs_update = true
每 5 分钟唤醒
    ↓ 检测 needs_update
    → true：获取最新数据，刷新屏幕，清标志，进入睡眠
    → false：直接进入睡眠
```

## 字体说明

中文字体使用 Google Fonts 的 Noto Sans SC（通过 `gfonts://` 方式加载）。如果显示特定字符缺失，可在 ESPHome 日志中看到警告提示，编辑 `glyphs` 字段添加缺失字。

## 版本历史

见 [CHANGELOG.md](./CHANGELOG.md)