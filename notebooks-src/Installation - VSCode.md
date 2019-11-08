---
title: "Installation - VSCode"
description: "Installing the Imandra IDE plugin in VSCode"
kernel: imandra
slug: installation-vscode
---

# VS Code

If you use VS Code, you can also install the [Imandra IDE Extension](https://marketplace.visualstudio.com/items?itemName=aestheticintegration.iml-vscode) plugin to help with development, providing things like completion and syntax highlighting as well as full asynchronous proof checking and semantic editing, meaning you can see proved theorems, counterexamples and instances within the IDE as you type. 

In order to install the standard extension, first follow the instructions above for installing Imandra. Then in VSCode itself VSCode go to the extensions view by following the instructions about the [Extension Marketplace](https://code.visualstudio.com/docs/editor/extension-gallery) and searching for `Imandra IDE`. 

The extension will open automatically when a file with extension `.iml` or `.ire` is opened. The extension will look for the correct version of `ocamlmerlin` on the opam switch associated with the folder in which the opened `.iml` or `.ire` file resides (defaulting to the current global switch). We recommend that the current global switch is that produced by the [recommended installation](Installation%20-%20Simple.md) of Imandra, as that contains all the artifacts to facilitate correct Imandra type inference, asynchronous proof checking and other language server features. Below are example images of the type information the Imandra IDE provides in VSCode.
<table style="width:100%">
<tr>
    <th><img src="https://storage.googleapis.com/imandra-assets/images/docs/ImandraVSCodeIDE1.png"></th>
    <th><img src = "https://storage.googleapis.com/imandra-assets/images/docs/ImandraVSCodeIDE2.png"></th>
</tr>
</table>

