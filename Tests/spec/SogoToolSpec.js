import config from '../lib/config'
import { mkdtempSync, rmSync } from 'fs'

const os = require('os')
const path = require('path')
const { execSync } = require('child_process')

describe('sogo-tool tests', function() {
  let tmpdir, isRoot

  beforeAll(function() {
    const { uid } = os.userInfo()
    isRoot = (uid == 0)
  })

  beforeEach(function() {
    tmpdir = mkdtempSync(path.join(os.tmpdir(), 'sogo-'))
    if (isRoot) {
      execSync(`chown -R sogo:sogo ${tmpdir}`)
    }
  })

  afterEach(function() {
    rmSync(tmpdir, { recursive: true, force: true })
  })

  it('backup', async function() {
    const sudo = isRoot ? `sudo -u sogo ` : ``
    try {
      execSync(`${sudo}sogo-tool backup ${tmpdir} ${config.username} 2>&1`)
    } catch (err) {
      fail(err)
    }
  })
})