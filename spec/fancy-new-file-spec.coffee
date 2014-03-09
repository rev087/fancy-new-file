FancyNewFile = require '../lib/fancy-new-file'

# Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
#
# To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
# or `fdescribe`). Remove the `f` to unfocus the block.

describe "FancyNewFile", ->
  activationPromise = null

  beforeEach ->
    atom.workspaceView = new WorkspaceView
    activationPromise = atom.packages.activatePackage('fancyNewFile')

  describe "when the fancy-new-file:toggle event is triggered", ->
    it "attaches and then detaches the view", ->
      expect(atom.workspaceView.find('.fancy-new-file')).not.toExist()

      # This is an activation event, triggering it will cause the package to be
      # activated.
      atom.workspaceView.trigger 'fancy-new-file:toggle'

      waitsForPromise ->
        activationPromise

      runs ->
        expect(atom.workspaceView.find('.fancy-new-file')).toExist()
        atom.workspaceView.trigger 'fancy-new-file:toggle'
        expect(atom.workspaceView.find('.fancy-new-file')).not.toExist()
