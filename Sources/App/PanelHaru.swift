import AppKit
import SwiftUI

/// Contenido del panel flotante: buscador, secciones y pie.
struct PanelHaru: View {
    @EnvironmentObject var store: HaruStore
    let cerrarPanel: () -> Void

    @State private var seleccion: String?
    /// Lista a confirmar de "Apagar todo lo que no uso". La confirmación va en
    /// el pie y no en un diálogo: un diálogo le saca el foco al panel y lo esconde.
    @State private var confirmando: [Proyecto]?
    @FocusState private var buscadorEnfocado: Bool

    var body: some View {
        let secciones = store.secciones
        VStack(spacing: 0) {
            buscador
            Divider()
            ScrollViewReader { lector in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        Color.clear.frame(height: 0).id(Self.inicio)
                        if secciones.todos.isEmpty { vacio }
                        seccion("Abiertos", secciones.abiertos)
                        seccion("Favoritos", secciones.favoritos)
                        seccion(store.busqueda.isEmpty ? "Más usados" : "Resultados", secciones.resto)
                    }
                    .padding(8)
                }
                .onChange(of: seleccion) { _, nueva in
                    if let nueva { lector.scrollTo(nueva) }
                }
                .onChange(of: store.busqueda) { _, _ in irAlInicio(lector) }
                // Al mostrarse el panel: foco en el buscador y la lista arriba
                // de todo, con el primero seleccionado.
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
                    buscadorEnfocado = true
                    confirmando = nil
                    irAlInicio(lector)
                }
            }
            Divider()
            pie
        }
        .frame(width: 560, height: 520)
        .background(.regularMaterial)
    }

    private static let inicio = "inicio"

    private func irAlInicio(_ lector: ScrollViewProxy) {
        seleccion = store.secciones.todos.first?.id
        lector.scrollTo(Self.inicio, anchor: .top)
    }

    private var buscador: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Buscar proyecto…", text: $store.busqueda)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .focused($buscadorEnfocado)
                .onSubmit(abrirSeleccion)
                .onKeyPress(.upArrow) { mover(-1); return .handled }
                .onKeyPress(.downArrow) { mover(1); return .handled }
                .onKeyPress(.escape) { cerrarPanel(); return .handled }
        }
        .padding(14)
    }

    @ViewBuilder
    private var vacio: some View {
        if !store.proyectos.isEmpty {
            Text("Ningún proyecto coincide con la búsqueda.")
                .font(.callout).foregroundStyle(.secondary).padding(12)
        } else if store.buscandoProyectos || !store.escaneoInicialListo {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Buscando proyectos…").font(.callout).foregroundStyle(.secondary)
            }
            .padding(12)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("No encontré proyectos en \(raicesLegibles).")
                    .font(.callout)
                Text("Haru busca carpetas con .git, package.json, compose.yml y otros archivos de proyecto. Elegí dónde buscar:")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Elegir carpetas de proyectos…") {
                    cerrarPanel()
                    SelectorCarpetas.elegir(store: store)
                }
            }
            .padding(12)
        }
    }

    private var raicesLegibles: String {
        store.raices
            .map { $0.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
            .joined(separator: ", ")
    }

    @ViewBuilder
    private func seccion(_ titulo: String, _ lista: [Proyecto]) -> some View {
        if !lista.isEmpty {
            Text(titulo.uppercased())
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .padding(.horizontal, 8).padding(.top, 8)
            ForEach(lista) { p in
                FilaProyecto(proyecto: p, seleccionada: p.id == seleccion)
                    .id(p.id)
                    .onTapGesture { seleccion = p.id }
            }
        }
    }

    @ViewBuilder
    private var pie: some View {
        HStack(spacing: 8) {
            if let lista = confirmando {
                Text(lista.isEmpty
                     ? "No hay Docker prendido sin usar."
                     : "¿Apagar Docker de \(lista.map(\.nombre).joined(separator: ", "))?")
                    .font(.callout).lineLimit(2)
                Spacer()
                Button(lista.isEmpty ? "Listo" : "Cancelar") { confirmando = nil }
                if !lista.isEmpty {
                    Button("Apagar") {
                        confirmando = nil
                        Task { await store.apagar(lista) }
                    }
                }
            } else {
                Text("\(store.cantidadConDocker) con Docker prendido")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Apagar todo lo que no uso") {
                    Task {
                        if let lista = await store.sinUso() { confirmando = lista }
                        else { store.avisar("No pude leer Docker o las ventanas de VS Code: no apago nada") }
                    }
                }
            }
        }
        .padding(10)
    }

    private func mover(_ paso: Int) {
        let todos = store.secciones.todos
        guard !todos.isEmpty else { return }
        let actual = todos.firstIndex { $0.id == seleccion } ?? -1
        seleccion = todos[min(max(actual + paso, 0), todos.count - 1)].id
    }

    /// Enter: abre el seleccionado (si ya estaba abierto, VS Code lo trae al
    /// frente) y esconde el panel, como Spotlight.
    private func abrirSeleccion() {
        guard let p = store.secciones.todos.first(where: { $0.id == seleccion }) else { return }
        Task { await store.abrir(p) }
        cerrarPanel()
    }
}
