// Disco Livre — gaveta lateral que mostra e libera espaço no Mac.
// Encoste o mouse na borda direita da tela e ela desliza pra dentro.
// Usa a ferramenta `disco-livre` (~/.local/bin) por baixo.

import AppKit
import ServiceManagement
import SwiftUI

// MARK: - Ferramenta de linha de comando

enum CLI {
    static let caminho = NSHomeDirectory() + "/.local/bin/disco-livre"
    static let log = NSHomeDirectory() + "/Library/Logs/disco-livre.log"
    static var existe: Bool { FileManager.default.isExecutableFile(atPath: caminho) }

    static func rodar(_ args: [String]) async -> String {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/bin/zsh")
                p.arguments = [caminho] + args
                let saida = Pipe()
                p.standardOutput = saida
                p.standardError = FileHandle.nullDevice
                p.standardInput = FileHandle.nullDevice
                do { try p.run() } catch { cont.resume(returning: ""); return }
                let dados = saida.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                cont.resume(returning: String(decoding: dados, as: UTF8.self))
            }
        }
    }
}

// MARK: - Dados

struct Resumo: Decodable {
    var livre: Int64
    var total: Int64
    var metaKb: Int64
    var metaGb: Int
    var vigilancia: Bool
    var autoLimpeza: Bool
    var intervalo: Int
    var tendenciaKb: Int64?
    var lixo: [Lixo]
    var crashes: [Crash]
    var tarefas: [Tarefa]
    var remoto: [Remoto]
}

struct Lixo: Decodable, Identifiable {
    var kb: Int64; var desc: String; var bloqueado: Bool; var cam: String
    var id: String { cam }
}

struct Crash: Decodable, Identifiable {
    var n: Int; var kb: Int64; var app: String; var cam: String
    var id: String { cam }
}

struct Tarefa: Decodable, Identifiable {
    var tipo: String; var label: String; var info: String; var prog: String
    var id: String { label }
}

struct Remoto: Decodable, Identifiable {
    var app: String; var porta: String; var perfil: String
    var id: String { app + porta }
}

struct Pasta: Decodable, Identifiable {
    var kb: Int64; var cam: String; var oculta: Bool; var dica: String
    var id: String { cam }
    var nome: String { (cam as NSString).lastPathComponent }
    var curto: String { cam.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
}

/// GB/MB decimais, igual ao Finder.
func tamanho(_ kb: Int64) -> String {
    let b = Double(abs(kb)) * 1024
    let f = NumberFormatter()
    f.locale = Locale(identifier: "pt_BR")
    if b >= 1e9 {
        f.minimumFractionDigits = 1; f.maximumFractionDigits = 1
        return (f.string(from: NSNumber(value: b / 1e9)) ?? "") + " GB"
    }
    f.maximumFractionDigits = 0
    if b >= 1e6 { return (f.string(from: NSNumber(value: b / 1e6)) ?? "") + " MB" }
    return "\(abs(kb)) KB"
}

@MainActor
final class Estado: ObservableObject {
    @Published var resumo: Resumo?
    @Published var pastas: [Pasta]?
    @Published var carregando = false
    @Published var medindoPastas = false
    @Published var limpando = false
    @Published var aviso: String?

    var aoAtualizar: (() -> Void)?
    private var ultimaAtualizacao = Date.distantPast
    private var tarefaMeta: Task<Void, Never>?

    func atualizar(seVelho: Bool = false) async {
        guard CLI.existe else { aoAtualizar?(); return }
        if seVelho && Date().timeIntervalSince(ultimaAtualizacao) < 60 { return }
        if carregando { return }
        carregando = true
        let txt = await CLI.rodar(["dados", "resumo"])
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        if let r = try? dec.decode(Resumo.self, from: Data(txt.utf8)) {
            resumo = r
            ultimaAtualizacao = Date()
        }
        carregando = false
        aoAtualizar?()
    }

    func medirPastas() async {
        medindoPastas = true
        let txt = await CLI.rodar(["dados", "pastas"])
        pastas = (try? JSONDecoder().decode([Pasta].self, from: Data(txt.utf8))) ?? []
        medindoPastas = false
    }

    func limpar() async {
        let antes = resumo?.livre ?? 0
        limpando = true
        aviso = nil
        _ = await CLI.rodar(["limpar", "--executar", "--sim"])
        ultimaAtualizacao = .distantPast
        await atualizar()
        limpando = false
        let ganho = (resumo?.livre ?? 0) - antes
        aviso = ganho > 102_400 ? "Pronto! Liberei \(tamanho(ganho))." : "Pronto! Lixo limpo."
    }

    func mudarMeta(_ gb: Int) {
        resumo?.metaGb = gb
        resumo?.metaKb = Int64(gb) * 976_562
        aoAtualizar?()
        tarefaMeta?.cancel()
        tarefaMeta = Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
            _ = await CLI.rodar(["config", "meta", "\(gb)"])
        }
    }

    func mudarVigilancia(_ ligar: Bool) async {
        resumo?.vigilancia = ligar
        _ = await CLI.rodar([ligar ? "ativar" : "desativar"])
        ultimaAtualizacao = .distantPast
        await atualizar()
    }

    func mudarAutoLimpeza(_ ligar: Bool) async {
        resumo?.autoLimpeza = ligar
        _ = await CLI.rodar(["config", "auto-limpeza", ligar ? "sim" : "nao"])
    }

    func pausar(_ label: String) async {
        _ = await CLI.rodar(["pausar-tarefa", label])
        ultimaAtualizacao = .distantPast
        await atualizar()
        aviso = "Tarefa \(label) pausada."
    }
}

// MARK: - Interface

struct Cartao<Conteudo: View>: View {
    let titulo: String
    let icone: String
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(titulo, systemImage: icone)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            conteudo
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
    }
}

struct BarraEspaco: View {
    let r: Resumo

    var cor: Color {
        if r.livre < r.metaKb { return .red }
        if r.livre < r.metaKb + r.metaKb / 3 { return .orange }
        return .green
    }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width
            let usado = CGFloat(r.total - r.livre) / CGFloat(max(r.total, 1))
            let limite = CGFloat(r.total - r.metaKb) / CGFloat(max(r.total, 1))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule().fill(cor.gradient).frame(width: max(10, w * usado))
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.primary.opacity(0.7))
                    .frame(width: 2, height: 20)
                    .offset(x: w * limite - 1)
                    .help("Sua meta: o disco não deve passar deste ponto")
            }
        }
        .frame(height: 12)
        .padding(.vertical, 4)
    }
}

struct PainelView: View {
    @EnvironmentObject var e: Estado
    @AppStorage("bordaAtiva") var bordaAtiva = true
    @State private var confirmando = false
    @State private var iniciarComMac = SMAppService.mainApp.status == .enabled
    var fechar: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            cabecalho
            Divider().opacity(0.4)
            if !CLI.existe {
                semFerramenta
            } else if let r = e.resumo {
                ScrollView {
                    VStack(spacing: 12) {
                        espaco(r)
                        alertas(r)
                        lixo(r)
                        pastas
                        ajustes(r)
                        rodape
                    }
                    .padding(14)
                }
            } else {
                Spacer()
                ProgressView("Olhando o disco…").controlSize(.small)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var cabecalho: some View {
        HStack(spacing: 8) {
            Image(systemName: "internaldrive.fill").foregroundStyle(.green)
            Text("Disco Livre").font(.headline)
            Spacer()
            if e.carregando { ProgressView().controlSize(.small) }
            Button { Task { await e.atualizar() } } label: { Image(systemName: "arrow.clockwise") }
                .help("Atualizar")
            Button { fechar() } label: { Image(systemName: "xmark") }
                .help("Fechar")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    var semFerramenta: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "wrench.and.screwdriver").font(.largeTitle).foregroundStyle(.secondary)
            Text("Falta instalar a ferramenta").font(.headline)
            Text("Na pasta do disco-livre, rode ./install.sh no Terminal.")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    func espaco(_ r: Resumo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(tamanho(r.livre)).font(.system(size: 34, weight: .bold, design: .rounded))
                Text("livres de \(tamanho(r.total))").foregroundStyle(.secondary)
            }
            BarraEspaco(r: r)
            if r.livre >= r.metaKb {
                Label("\(tamanho(r.livre - r.metaKb)) acima da sua meta de \(r.metaGb) GB", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green).font(.callout)
            } else {
                Label("Faltam \(tamanho(r.metaKb - r.livre)) pra sua meta de \(r.metaGb) GB", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red).font(.callout)
            }
            if let t = r.tendenciaKb, abs(t) > 1_000_000 {
                Text(t < 0 ? "↓ perdeu \(tamanho(t)) nos últimos 7 dias" : "↑ ganhou \(tamanho(t)) nos últimos 7 dias")
                    .font(.caption).foregroundStyle(t < 0 ? .orange : .secondary)
            }
        }
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    func alertas(_ r: Resumo) -> some View {
        if !r.crashes.isEmpty || !r.tarefas.isEmpty || !r.remoto.isEmpty {
            Cartao(titulo: "Atenção", icone: "exclamationmark.triangle") {
                ForEach(r.crashes) { c in
                    linhaAlerta(icone: "xmark.octagon.fill", cor: .red,
                                titulo: "\(c.app) está crashando sem parar",
                                texto: "\(c.n) relatórios de crash (\(tamanho(c.kb))). Limpe abaixo e reinicie o app.")
                }
                ForEach(r.tarefas) { t in
                    HStack(alignment: .top) {
                        linhaAlerta(icone: t.tipo == "reabre" ? "arrow.triangle.2.circlepath" : "exclamationmark.circle.fill",
                                    cor: t.tipo == "reabre" ? .orange : .red,
                                    titulo: t.label,
                                    texto: t.tipo == "reabre"
                                        ? "Abre o \(t.info) sozinho e reabre se você fechar."
                                        : "Tarefa em segundo plano terminando com erro (código \(t.info)).")
                        Button("Pausar") { Task { await e.pausar(t.label) } }
                            .controlSize(.small)
                            .help("Para a tarefa e impede que volte ao reiniciar. Dá pra desfazer no Terminal: disco-livre religar-tarefa \(t.label)")
                    }
                }
                ForEach(r.remoto) { rm in
                    linhaAlerta(icone: "dot.radiowaves.left.and.right", cor: .orange,
                                titulo: "\(rm.app) com controle remoto ligado",
                                texto: "Qualquer programa do Mac pode comandar esse navegador. Se não é uma automação sua, feche.")
                }
            }
        }
    }

    func linhaAlerta(icone: String, cor: Color, titulo: String, texto: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icone).foregroundStyle(cor).frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(titulo).font(.callout.weight(.medium)).lineLimit(2)
                Text(texto).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    func lixo(_ r: Resumo) -> some View {
        let itens = r.lixo.sorted { $0.kb > $1.kb }
        let total = itens.filter { !$0.bloqueado }.reduce(Int64(0)) { $0 + $1.kb }
        return Cartao(titulo: "Lixo seguro", icone: "trash") {
            if itens.isEmpty {
                Text("Nada pra limpar agora 👌").foregroundStyle(.secondary)
            }
            ForEach(itens) { i in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(i.desc).lineLimit(1)
                        if i.bloqueado {
                            Text("feche o app pra limpar").font(.caption2).foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    Text(tamanho(i.kb)).monospacedDigit().foregroundStyle(.secondary)
                }
                .font(.callout)
                .opacity(i.bloqueado ? 0.55 : 1)
            }
            if total > 0 {
                Text("Tudo isso se recria sozinho. Seus arquivos não são tocados.")
                    .font(.caption).foregroundStyle(.secondary)
                if e.limpando {
                    HStack { ProgressView().controlSize(.small); Text("Limpando…") }
                } else if confirmando {
                    HStack {
                        Text("Apagar \(tamanho(total))?").font(.callout.weight(.medium))
                        Spacer()
                        Button("Cancelar") { confirmando = false }
                        Button("Limpar") {
                            confirmando = false
                            Task { await e.limpar() }
                        }
                        .buttonStyle(.borderedProminent).tint(.green)
                    }
                } else {
                    Button { confirmando = true } label: {
                        Label("Limpar \(tamanho(total))", systemImage: "sparkles").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(.green).controlSize(.large)
                }
            }
            if let a = e.aviso {
                Label(a, systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.callout)
            }
        }
    }

    var pastas: some View {
        Cartao(titulo: "Maiores pastas", icone: "folder") {
            if e.medindoPastas {
                HStack { ProgressView().controlSize(.small); Text("Medindo… leva uns 15 segundos").foregroundStyle(.secondary) }
                    .font(.callout)
            } else if let lista = e.pastas {
                ForEach(lista.prefix(12)) { p in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(p.nome).font(.callout.weight(.medium)).lineLimit(1)
                            if p.oculta {
                                Text("oculta")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Capsule().fill(Color.orange.opacity(0.2)))
                                    .foregroundStyle(.orange)
                                    .help("O Finder não mostra essa pasta")
                            }
                            Spacer()
                            Text(tamanho(p.kb)).monospacedDigit().font(.callout).foregroundStyle(.secondary)
                            Button { NSWorkspace.shared.open(URL(fileURLWithPath: p.cam)) } label: {
                                Image(systemName: "arrow.up.forward.square")
                            }
                            .buttonStyle(.borderless)
                            .help("Abrir no Finder")
                        }
                        Text(p.curto).font(.caption2).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                        if !p.dica.isEmpty {
                            Text(p.dica).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 2)
                }
                Button("Medir de novo") { Task { await e.medirPastas() } }.controlSize(.small)
            } else {
                Text("Descubra o que está ocupando espaço, inclusive pastas que o Finder esconde.")
                    .font(.caption).foregroundStyle(.secondary)
                Button { Task { await e.medirPastas() } } label: {
                    Label("Medir pastas", systemImage: "magnifyingglass").frame(maxWidth: .infinity)
                }
            }
        }
    }

    func ajustes(_ r: Resumo) -> some View {
        Cartao(titulo: "Ajustes", icone: "gearshape") {
            Stepper(value: Binding(get: { r.metaGb }, set: { e.mudarMeta($0) }), in: 5...500, step: 5) {
                HStack {
                    Text("Meta de espaço livre")
                    Spacer()
                    Text("\(r.metaGb) GB").monospacedDigit().fontWeight(.semibold)
                }
            }
            Toggle(isOn: Binding(get: { r.vigilancia }, set: { v in Task { await e.mudarVigilancia(v) } })) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Vigiar sozinho")
                    Text("A cada \(r.intervalo)h. Avisa abaixo da meta e se um app crashar em loop.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: Binding(get: { r.autoLimpeza }, set: { v in Task { await e.mudarAutoLimpeza(v) } })) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Limpar sozinho abaixo da meta")
                    Text("Apaga só o lixo seguro e te avisa quanto liberou.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .disabled(!r.vigilancia)
            Toggle("Abrir ao encostar o mouse na borda direita", isOn: $bordaAtiva)
            Toggle("Abrir ao ligar o Mac", isOn: Binding(get: { iniciarComMac }, set: { v in
                do {
                    if v { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    iniciarComMac = v
                } catch {
                    e.aviso = nil
                    iniciarComMac = SMAppService.mainApp.status == .enabled
                }
            }))
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .font(.callout)
    }

    var rodape: some View {
        HStack {
            Button("Histórico de limpezas") { NSWorkspace.shared.open(URL(fileURLWithPath: CLI.log)) }
            Spacer()
            Button("Sair do Disco Livre") { NSApp.terminate(nil) }
        }
        .buttonStyle(.borderless)
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }
}

// MARK: - Gaveta (painel flutuante)

final class Gaveta: NSPanel {
    init(conteudo: some View) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 380, height: 700),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovable = false
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true

        let fundo = NSVisualEffectView()
        fundo.material = .popover
        fundo.blendingMode = .behindWindow
        fundo.state = .active
        fundo.maskImage = Gaveta.mascara(raio: 16)

        let host = NSHostingView(rootView: conteudo)
        host.frame = fundo.bounds
        host.autoresizingMask = [.width, .height]
        fundo.addSubview(host)
        contentView = fundo
    }

    override var canBecomeKey: Bool { true }

    static func mascara(raio: CGFloat) -> NSImage {
        let d = raio * 2 + 1
        let img = NSImage(size: NSSize(width: d, height: d), flipped: false) { r in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: r, xRadius: raio, yRadius: raio).fill()
            return true
        }
        img.capInsets = NSEdgeInsets(top: raio, left: raio, bottom: raio, right: raio)
        img.resizingMode = .stretch
        return img
    }
}

// MARK: - App

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let estado = Estado()
    var painel: Gaveta!
    var item: NSStatusItem!
    var monitores: [Any] = []
    var timerBorda: Timer?
    var timerSaida: Timer?
    var visivel = false
    var fixo = false   // aberta pelo ícone: só fecha com clique fora

    let largura: CGFloat = 380
    let margem: CGFloat = 8

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.accessory)

        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "internaldrive", accessibilityDescription: "Disco Livre")
        item.button?.imagePosition = .imageLeading
        item.button?.target = self
        item.button?.action = #selector(cliqueNoIcone)

        painel = Gaveta(conteudo: PainelView(fechar: { [weak self] in self?.esconder() }).environmentObject(estado))
        estado.aoAtualizar = { [weak self] in self?.atualizarIcone() }

        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved], handler: { [weak self] _ in
            Task { @MainActor in self?.mouseMexeu() }
        }) { monitores.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved], handler: { [weak self] ev in
            Task { @MainActor in self?.mouseMexeu() }
            return ev
        }) { monitores.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            Task { @MainActor in self?.cliqueFora() }
        }) { monitores.append(m) }

        Task { await estado.atualizar() }
        if CommandLine.arguments.contains("--mostrar") { mostrar(fixo: true) }
        Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.estado.atualizar() }
        }
    }

    func atualizarIcone() {
        guard let b = item.button else { return }
        guard let r = estado.resumo else { b.title = ""; return }
        let gb = Int((Double(r.livre) * 1024 / 1e9).rounded())
        let abaixo = r.livre < r.metaKb
        b.title = " \(gb) GB"
        b.image = NSImage(systemSymbolName: abaixo ? "exclamationmark.triangle.fill" : "internaldrive",
                          accessibilityDescription: "Disco Livre")
        b.contentTintColor = abaixo ? .systemRed : nil
    }

    @objc func cliqueNoIcone() {
        if visivel { esconder() } else { mostrar(fixo: true) }
    }

    func telaDoMouse() -> NSScreen {
        let p = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    func mouseMexeu() {
        let p = NSEvent.mouseLocation
        if !visivel {
            guard UserDefaults.standard.object(forKey: "bordaAtiva") as? Bool ?? true else { return }
            let f = telaDoMouse().frame
            let naBorda = p.x >= f.maxX - 2 && p.y > f.minY + 60 && p.y < f.maxY - 60
            if naBorda {
                if timerBorda == nil {
                    // espera um instante pra não abrir quando o mouse só passa pela borda
                    timerBorda = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { [weak self] _ in
                        Task { @MainActor in
                            guard let self else { return }
                            self.timerBorda = nil
                            let q = NSEvent.mouseLocation
                            if q.x >= self.telaDoMouse().frame.maxX - 3 { self.mostrar(fixo: false) }
                        }
                    }
                }
            } else {
                timerBorda?.invalidate(); timerBorda = nil
            }
        } else if !fixo {
            if painel.frame.insetBy(dx: -24, dy: -24).contains(p) {
                timerSaida?.invalidate(); timerSaida = nil
            } else if timerSaida == nil {
                timerSaida = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
                    Task { @MainActor in
                        guard let self else { return }
                        self.timerSaida = nil
                        if !self.painel.frame.insetBy(dx: -24, dy: -24).contains(NSEvent.mouseLocation) { self.esconder() }
                    }
                }
            }
        }
    }

    func cliqueFora() {
        guard visivel, !painel.frame.contains(NSEvent.mouseLocation) else { return }
        esconder()
    }

    func mostrar(fixo: Bool) {
        self.fixo = fixo
        let tela = fixo ? (item.button?.window?.screen ?? telaDoMouse()) : telaDoMouse()
        let v = tela.visibleFrame
        let altura = min(v.height - margem * 2, 860)
        let fim = NSRect(x: tela.frame.maxX - largura - margem, y: v.maxY - margem - altura,
                         width: largura, height: altura)
        if !visivel {
            var inicio = fim
            inicio.origin.x = tela.frame.maxX + 4
            painel.setFrame(inicio, display: false)
            painel.alphaValue = 0
        }
        visivel = true
        painel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { c in
            c.duration = 0.22
            c.timingFunction = CAMediaTimingFunction(name: .easeOut)
            painel.animator().setFrame(fim, display: true)
            painel.animator().alphaValue = 1
        }
        Task { await estado.atualizar(seVelho: true) }
    }

    func esconder() {
        guard visivel else { return }
        visivel = false
        fixo = false
        timerSaida?.invalidate(); timerSaida = nil
        var fim = painel.frame
        fim.origin.x = (painel.screen?.frame.maxX ?? fim.maxX) + 4
        NSAnimationContext.runAnimationGroup({ c in
            c.duration = 0.18
            c.timingFunction = CAMediaTimingFunction(name: .easeIn)
            painel.animator().setFrame(fim, display: true)
            painel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                if self?.visivel == false { self?.painel.orderOut(nil) }
            }
        })
    }
}

@main
enum DiscoLivreApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = MainActor.assumeIsolated { AppDelegate() }
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
