import { beforeEach, describe, expect, it, vi } from 'vitest'
import { Kysely, sql } from 'kysely'

// 對假的 callPlugin 測：dialect 只把已編譯的 SQL 與 bind 轉發給 `sqlite.open`／`sqlite.exec`
const calls: Array<{ method: string, payload: Record<string, unknown> }> = []
let responder: (method: string, payload: Record<string, unknown>) => unknown = () => ({ ok: true })

vi.mock('@aqutter/aqutter', () => ({
  callPlugin: async (_id: string, method: string, payload: Record<string, unknown>) => {
    calls.push({ method, payload })
    return responder(method, payload)
  },
  isPluginSupported: () => true,
}))

const { AqutterSqliteDialect, sqlite } = await import('../src/index')

interface Database {
  people: { id: number, name: string | null, avatar: Uint8Array | null }
}

const newDb = (config: { name?: string, path?: string } = { name: 'app' }) =>
  new Kysely<Database>({ dialect: new AqutterSqliteDialect(config) })

describe('AqutterSqliteDialect', () => {
  beforeEach(() => {
    calls.length = 0
    responder = () => ({ ok: true })
  })

  it('opens the database with the name once, on first use', async () => {
    responder = method => (method === 'open' ? { ok: true } : { rows: [] })
    const db = newDb({ name: 'app' })
    await db.selectFrom('people').selectAll().execute()
    await db.selectFrom('people').selectAll().execute()
    expect(calls.filter(call => call.method === 'open')).toEqual([{ method: 'open', payload: { name: 'app', path: undefined } }])
  })

  it('uses the path as the connection key when given, and path wins over name', async () => {
    responder = method => (method === 'open' ? { ok: true } : { rows: [] })
    const db = newDb({ name: 'ignored', path: '/data/app.sqlite' })
    await db.selectFrom('people').selectAll().execute()
    const exec = calls.find(call => call.method === 'exec')!
    expect(exec.payload.name).toBe('/data/app.sqlite')
  })

  it('needs a name or a path', async () => {
    const db = newDb({})
    await expect(db.selectFrom('people').selectAll().execute()).rejects.toThrow(/Either name or path/)
  })

  it('forwards the compiled SQL and the bind parameters, and returns rows', async () => {
    responder = (method) => {
      if (method === 'open') {
        return { ok: true }
      }
      return { rows: [{ id: 1, name: 'Ann', avatar: null }] }
    }
    const db = newDb()
    const rows = await db.selectFrom('people').selectAll().where('name', '=', 'Ann').execute()
    expect(rows).toEqual([{ id: 1, name: 'Ann', avatar: null }])
    const exec = calls.find(call => call.method === 'exec')!
    expect(exec.payload).toEqual({ name: 'app', sql: 'select * from "people" where "name" = ?', bind: ['Ann'] })
  })

  it('sends BLOB parameters as Uint8Array, untouched', async () => {
    responder = method => (method === 'open' ? { ok: true } : { changes: 1, insertId: 7 })
    const bytes = new Uint8Array([0, 1, 250, 255])
    const db = newDb()
    const result = await db.insertInto('people').values({ id: 7, name: 'Ann', avatar: bytes }).executeTakeFirst()
    const exec = calls.find(call => call.method === 'exec')!
    expect((exec.payload.bind as unknown[])[2]).toBe(bytes)
    expect(result.insertId).toBe(7n)
    expect(result.numInsertedOrUpdatedRows).toBe(1n)
  })

  it('turns changes and insertId into bigint', async () => {
    responder = method => (method === 'open' ? { ok: true } : { changes: 3 })
    const db = newDb()
    const result = await db.updateTable('people').set({ name: 'x' }).executeTakeFirst()
    expect(result.numUpdatedRows).toBe(3n)
  })

  it('runs a transaction as BEGIN, the statements, then COMMIT over sqlite.exec', async () => {
    responder = method => (method === 'open' ? { ok: true } : { changes: 1, insertId: 1 })
    const db = newDb()
    await db.transaction().execute(async (trx) => {
      await trx.insertInto('people').values({ id: 1, name: 'Ann', avatar: null }).execute()
    })
    const statements = calls.filter(call => call.method === 'exec').map(call => call.payload.sql)
    expect(statements).toEqual(['BEGIN', 'insert into "people" ("id", "name", "avatar") values (?, ?, ?)', 'COMMIT'])
  })

  it('rolls back when the transaction throws', async () => {
    responder = method => (method === 'open' ? { ok: true } : { changes: 1 })
    const db = newDb()
    await expect(db.transaction().execute(async () => {
      throw new Error('boom')
    })).rejects.toThrow('boom')
    const statements = calls.filter(call => call.method === 'exec').map(call => call.payload.sql)
    expect(statements).toEqual(['BEGIN', 'ROLLBACK'])
  })

  it('raw sql goes through as well', async () => {
    responder = method => (method === 'open' ? { ok: true } : { rows: [{ n: 2 }] })
    const db = newDb()
    const result = await sql<{ n: number }>`select count(*) as n from people`.execute(db)
    expect(result.rows).toEqual([{ n: 2 }])
  })

  it('streaming is not supported', async () => {
    const db = newDb()
    const iterator = db.selectFrom('people').selectAll().stream()
    await expect(iterator.next()).rejects.toThrow()
  })
})

describe('sqlite API', () => {
  it('isSupported follows the plugin capability', () => {
    expect(sqlite.isSupported()).toBe(true)
  })
})
