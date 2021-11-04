import config from '../lib/config'
import { mkdtempSync, rmSync } from 'fs'

const os = require('os')
const path = require('path')
const { execSync } = require('child_process')

describe('sogo-tool tests', function() {
  let tmpdir

  beforeEach(function() {
    tmpdir = mkdtempSync(path.join(os.tmpdir(), 'sogo-'))
  })

  afterEach(function() {
    rmSync(tmpdir, { recursive: true, force: true })
  })

  it('backup', async function() {
    execSync(`sogo-tool backup ${tmpdir} ${config.username}`, (error, stdout, stderr) => {
      expect(error).not.toBeDefined()
    })
  })
})