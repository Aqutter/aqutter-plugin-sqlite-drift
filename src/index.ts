import {
  SqliteAdapter,
  SqliteIntrospector,
  SqliteQueryCompiler,
  type CompiledQuery,
  type DatabaseConnection,
  type Dialect,
  type Driver,
  type QueryResult,
} from 'kysely'
import { callPlugin, isPluginSupported } from '@aqutter/aqutter'
import type { PluginDefinition } from '@aqutter/aqutter'

/* ------------------------------------------------------------------ *
 * 契約：plugin id `sqlite`，handler `sqlite.open`、`sqlite.exec`。
 * Dart 端是 `SqliteDriftPlugin`（drift）；契約與實作分開，日後換其他實作可沿用同一個 id 與契約。
 * ------------------------------------------------------------------ */

/** 綁定參數與回傳欄位值：BLOB 直接是 `Uint8Array`，不經 base64。 */
export type SqliteValue = null | number | string | boolean | Uint8Array

/** 開啟資料庫請求；`name` 與 `path` 至少提供其一（`path` 優先）。 */
export interface SqliteOpenRequest {
  /** 資料庫名稱，實際檔案為 App 文件目錄下的 `${name}.db`。 */
  name?: string
  /** 資料庫檔案的絕對路徑；提供時優先於 `name`。 */
  path?: string
}

/** 執行單句 SQL 的請求。 */
export interface SqliteExecRequest {
  /** 連線鍵：開啟時的 `path`（有提供時）否則 `name`。 */
  name: string
  /** 已由 Kysely 編譯的單句 SQL。 */
  sql: string
  /** 綁定參數。 */
  bind: SqliteValue[]
}

/** 執行結果：回傳資料列的語句回 `rows`；其他語句回 `changes` 與 `insertId`。 */
export interface SqliteExecResponse {
  rows?: Record<string, SqliteValue>[]
  changes?: number
  insertId?: number
}

/** 此 plugin 的契約：方法表（沒有事件）。 */
export type SqliteContract = PluginDefinition<
  {
    open: { req: SqliteOpenRequest, res: { ok: true } }
    exec: { req: SqliteExecRequest, res: SqliteExecResponse }
  },
  Record<string, never>
>

// 把契約併入全域 plugin 表：使用端即可用 callPlugin('sqlite', …) 得到完整型別
declare module '@aqutter/aqutter' {
  interface AqutterPluginRegistry {
    'sqlite': SqliteContract
  }
}

/** 網頁端 API。 */
export const sqlite = {
  /** 這個 App 是否裝了本 plugin（且本平台支援）。 */
  isSupported: (): boolean => isPluginSupported('sqlite', 'exec'),
  open: (request: SqliteOpenRequest) => callPlugin('sqlite', 'open', request),
  exec: (request: SqliteExecRequest) => callPlugin('sqlite', 'exec', request),
}

/* ------------------------------------------------------------------ *
 * Kysely dialect
 * ------------------------------------------------------------------ */

export interface AqutterSqliteDialectConfig {
  /** 資料庫名稱，實際檔案為 App 文件目錄下的 `${name}.db`。 */
  name?: string
  /** 直接指定資料庫絕對路徑（優先於 name）。 */
  path?: string
}

/** 連線鍵：`path` 優先，其次 `name`（與 Dart 端一致）。 */
const resolveKey = (config: AqutterSqliteDialectConfig): string => {
  if (config.path) {
    return config.path
  }
  if (config.name) {
    return config.name
  }
  throw new Error('[AqutterSqliteDialect] Either name or path is required')
}

const RAW_BEGIN = 'BEGIN'
const RAW_COMMIT = 'COMMIT'
const RAW_ROLLBACK = 'ROLLBACK'

class SqliteConnection implements DatabaseConnection {
  private readonly key: string

  constructor(key: string) {
    this.key = key
  }

  async executeQuery<R>(compiledQuery: CompiledQuery): Promise<QueryResult<R>> {
    const res = await sqlite.exec({
      name: this.key,
      sql: compiledQuery.sql,
      bind: compiledQuery.parameters as SqliteValue[],
    })

    const rows = (res.rows ?? []) as R[]
    if (rows.length > 0) {
      return { rows }
    }

    return {
      rows: [],
      numAffectedRows: res.changes !== undefined ? BigInt(res.changes) : undefined,
      insertId: res.insertId !== undefined && res.insertId !== null ? BigInt(res.insertId) : undefined,
    }
  }

  // eslint-disable-next-line require-yield
  async* streamQuery<R>(_compiledQuery: CompiledQuery, _chunkSize: number): AsyncIterableIterator<QueryResult<R>> {
    throw new Error('Streaming is not supported with SQLite')
  }

  /** 以 raw SQL 執行交易控制語句（Dart 端同一條序列化連線，語句順序與交易邊界成立）。 */
  async execRaw(sql: string): Promise<void> {
    await sqlite.exec({ name: this.key, sql, bind: [] })
  }
}

class SqliteDriver implements Driver {
  private readonly config: AqutterSqliteDialectConfig
  private connection: SqliteConnection | null = null

  constructor(config: AqutterSqliteDialectConfig) {
    this.config = config
  }

  async init(): Promise<void> {
    const key = resolveKey(this.config)
    await sqlite.open({ name: this.config.name, path: this.config.path })
    this.connection = new SqliteConnection(key)
  }

  async acquireConnection(): Promise<DatabaseConnection> {
    if (!this.connection) {
      await this.init()
    }
    return this.connection as SqliteConnection
  }

  async beginTransaction(connection: DatabaseConnection): Promise<void> {
    await (connection as SqliteConnection).execRaw(RAW_BEGIN)
  }

  async commitTransaction(connection: DatabaseConnection): Promise<void> {
    await (connection as SqliteConnection).execRaw(RAW_COMMIT)
  }

  async rollbackTransaction(connection: DatabaseConnection): Promise<void> {
    await (connection as SqliteConnection).execRaw(RAW_ROLLBACK)
  }

  async releaseConnection(): Promise<void> {
    // 單一連線常駐，release 時不做事
  }

  async destroy(): Promise<void> {
    // 連線由原生端管理生命週期，這裡不主動關閉
  }
}

/**
 * Aqutter 的 Kysely Dialect：JS 端只把已編譯的 SQL 與 bind 轉發給 plugin 的 `sqlite.exec`，
 * 查詢與交易由 Dart 端的 drift 執行器處理。
 *
 * ```ts
 * const db = new Kysely<Database>({ dialect: new AqutterSqliteDialect({ name: 'app' }) })
 * ```
 */
export class AqutterSqliteDialect implements Dialect {
  private readonly config: AqutterSqliteDialectConfig

  constructor(config: AqutterSqliteDialectConfig) {
    this.config = config
  }

  createDriver(): Driver {
    return new SqliteDriver(this.config)
  }

  createQueryCompiler() {
    return new SqliteQueryCompiler()
  }

  createAdapter() {
    return new SqliteAdapter()
  }

  createIntrospector(db: ConstructorParameters<typeof SqliteIntrospector>[0]) {
    return new SqliteIntrospector(db)
  }
}
