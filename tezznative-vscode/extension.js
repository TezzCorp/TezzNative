const vscode = require('vscode');
const { LanguageClient, TransportKind } = require('vscode-languageclient/node');

let client;

function activate(context) {
    console.log('TezzNative language support extension is now active!');

    // The LSP server is run via "tezzc lsp"
    const serverOptions = {
        run: { command: 'tezzc', args: ['lsp'], transport: TransportKind.stdio },
        debug: { command: 'tezzc', args: ['lsp'], transport: TransportKind.stdio }
    };

    const clientOptions = {
        documentSelector: [{ scheme: 'file', language: 'tezznative' }],
        synchronize: {
            fileEvents: vscode.workspace.createFileSystemWatcher('**/*.tn')
        }
    };

    client = new LanguageClient(
        'tezznativeLSP',
        'TezzNative Language Server',
        serverOptions,
        clientOptions
    );

    client.start();
}

function deactivate() {
    if (!client) {
        return undefined;
    }
    return client.stop();
}

module.exports = {
    activate,
    deactivate
};
