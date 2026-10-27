import { callPlugin, onPluginEvent } from '@aqutter/aqutter'
import type { PluginDefinition } from '@aqutter/aqutter'

/** 此 plugin 的契約：方法表與事件表。Dart 端 `SqliteDriftPlugin` 必須提供同名方法。 */
export type SqliteContract = PluginDefinition<
  {
    ping: { req: { message: string }, res: { echo: string } }
  },
  {
    tick: { count: number }
  }
>

// 把契約併入全域 plugin 表：使用端即可用 callPlugin('sqlite', …) 得到完整型別
declare module '@aqutter/aqutter' {
  interface AqutterPluginRegistry {
    'sqlite': SqliteContract
  }
}

/** 網頁端 API。 */
export const sqlite = {
  ping: (message: string) => callPlugin('sqlite', 'ping', { message }),
  onTick: (listener: (count: number) => void) => onPluginEvent('sqlite', 'tick', payload => listener(payload.count)),
}
