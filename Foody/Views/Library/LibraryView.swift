import SwiftUI
import SwiftData
import FoodyCore

/// База: продукты, сохранённые приёмы пищи, рецепты.
struct LibraryView: View {
    enum Segment: String, CaseIterable, Identifiable {
        case products = "Продукты", meals = "Приёмы пищи", recipes = "Рецепты"
        var id: String { rawValue }
    }

    @State private var section: Segment = .products
    @State private var search = ""
    @State private var showManualProduct = false
    @State private var showScan = false
    @State private var showNewMeal = false
    @State private var showNewRecipe = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Раздел", selection: $section) {
                    ForEach(Segment.allCases) { s in Text(s.rawValue).tag(s) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                switch section {
                case .products: ProductListView(search: search)
                case .meals: SavedMealListView(search: search)
                case .recipes: RecipeListView(search: search)
                }
            }
            .background(Theme.background)
            .navigationTitle("Продукты")
            .searchable(text: $search, prompt: "Поиск")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        switch section {
                        case .products:
                            Button { showScan = true } label: { Label("Сфотографировать этикетку", systemImage: "camera.viewfinder") }
                            Button { showManualProduct = true } label: { Label("Ввести вручную", systemImage: "square.and.pencil") }
                        case .meals:
                            Button { showNewMeal = true } label: { Label("Новый приём пищи", systemImage: "fork.knife") }
                        case .recipes:
                            Button { showNewRecipe = true } label: { Label("Новый рецепт", systemImage: "frying.pan") }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Добавить")
                }
            }
            .sheet(isPresented: $showManualProduct) {
                ProductFormView(mode: .create(ProductDraft()))
            }
            .sheet(isPresented: $showScan) {
                LabelScanFlowView { _ in }
            }
            .sheet(isPresented: $showNewMeal) {
                SavedMealFormView(meal: nil)
            }
            .sheet(isPresented: $showNewRecipe) {
                RecipeFormView(recipe: nil)
            }
        }
    }
}

// MARK: - Продукты

struct ProductListView: View {
    let search: String
    @Query(sort: \Product.name) private var products: [Product]
    @Environment(\.modelContext) private var context

    private var filtered: [Product] {
        let q = search.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return products }
        return products.filter { $0.name.localizedCaseInsensitiveContains(q) || $0.brand.localizedCaseInsensitiveContains(q) }
    }

    private var favorites: [Product] { filtered.filter { $0.isFavorite } }
    private var others: [Product] { filtered.filter { !$0.isFavorite } }

    var body: some View {
        if products.isEmpty {
            EmptyStateView(title: "Пока пусто",
                           message: "Добавьте первый продукт: сфотографируйте этикетку или введите значения вручную (кнопка «+»).",
                           symbol: "carrot")
        } else {
            List {
                if !favorites.isEmpty {
                    Section("Избранное") {
                        ForEach(favorites) { p in row(p) }
                    }
                }
                Section(favorites.isEmpty ? "Все продукты" : "Остальные") {
                    ForEach(others) { p in row(p) }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func row(_ p: Product) -> some View {
        NavigationLink {
            ProductDetailView(product: p)
        } label: {
            ProductRow(product: p)
        }
        .swipeActions(edge: .leading) {
            Button {
                p.isFavorite.toggle()
            } label: {
                Label(p.isFavorite ? "Убрать" : "В избранное", systemImage: p.isFavorite ? "star.slash" : "star")
            }
            .tint(Theme.fat)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                context.delete(p)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }
}

// MARK: - Сохранённые приёмы пищи

struct SavedMealListView: View {
    let search: String
    @Query(sort: \SavedMeal.name) private var meals: [SavedMeal]
    @Environment(\.modelContext) private var context
    @State private var editing: SavedMeal?

    private var filtered: [SavedMeal] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? meals : meals.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        if meals.isEmpty {
            EmptyStateView(title: "Нет сохранённых приёмов",
                           message: "Соберите свой обычный завтрак, обед или ужин из продуктов — потом он добавляется в дневник одним касанием.",
                           symbol: "fork.knife")
        } else {
            List {
                ForEach(MealCategory.allCases) { category in
                    let items = filtered.filter { $0.category == category }
                    if !items.isEmpty {
                        Section(category.title) {
                            ForEach(items) { m in
                                Button { editing = m } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(m.name)
                                            Text(m.subtitle).font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        MacroSummaryLine(facts: m.total, showKcal: false)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { context.delete(m) } label: { Label("Удалить", systemImage: "trash") }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .sheet(item: $editing) { meal in
                SavedMealFormView(meal: meal)
            }
        }
    }
}

// MARK: - Рецепты

struct RecipeListView: View {
    let search: String
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @Environment(\.modelContext) private var context

    private var filtered: [Recipe] {
        let q = search.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? recipes : recipes.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        if recipes.isEmpty {
            EmptyStateView(title: "Нет рецептов",
                           message: "Рецепт считает КБЖУ по весу готового блюда и стандартной порции — удобно для супов, каш и выпечки.",
                           symbol: "frying.pan")
        } else {
            List {
                ForEach(filtered) { r in
                    NavigationLink {
                        RecipeDetailView(recipe: r)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(r.name)
                            Text(r.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { context.delete(r) } label: { Label("Удалить", systemImage: "trash") }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}
