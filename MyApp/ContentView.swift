import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Data Models

enum BonusType: Equatable {
    case none
    case doubleLetter
    case tripleLetter
    case doubleWord
    case tripleWord
    case centerStar

    var label: String {
        switch self {
        case .none: return ""
        case .doubleLetter: return "DL"
        case .tripleLetter: return "TL"
        case .doubleWord: return "DW"
        case .tripleWord: return "TW"
        case .centerStar: return "★"
        }
    }

    var fillColor: Color {
        switch self {
        case .none: return Color(red: 0.90, green: 0.87, blue: 0.80)
        case .doubleLetter: return Color(red: 0.68, green: 0.85, blue: 0.92)
        case .tripleLetter: return Color(red: 0.25, green: 0.52, blue: 0.78)
        case .doubleWord, .centerStar: return Color(red: 0.95, green: 0.68, blue: 0.65)
        case .tripleWord: return Color(red: 0.86, green: 0.33, blue: 0.31)
        }
    }
}

struct GridPos: Hashable {
    let row: Int
    let col: Int
}

struct Tile: Identifiable, Equatable {
    let id = UUID()
    let letter: String
    let points: Int
}

struct TileSpec {
    let letter: String
    let points: Int
    let count: Int
}

struct BoardCell: Identifiable, Equatable {
    let id = UUID()
    let row: Int
    let col: Int
    let bonus: BonusType
    var tile: Tile? = nil
    var isLocked: Bool = false
}

struct MoveRecord: Identifiable, Equatable {
    let id = UUID()
    let player: String
    let words: [String]
    let points: Int
}

struct ScoredWord {
    let key: String
    let word: String
    let score: Int
}

// MARK: - ViewModel

@MainActor
final class WordGameViewModel: ObservableObject {
    let boardSize: Int = 11
    var centerIndex: Int { boardSize / 2 }

    @Published var grid: [[BoardCell]] = []
    @Published var rack: [Tile] = []
    @Published var tileBag: [Tile] = []
    @Published var selectedRackTileID: UUID? = nil
    @Published var playerScore: Int = 0
    @Published var statusMessage: String = "Tap a rack tile, then tap the board to place your first word on ★"
    @Published var moveHistory: [MoveRecord] = []

    init() {
        startNewGame()
    }

    func startNewGame() {
        playerScore = 0
        moveHistory.removeAll()
        selectedRackTileID = nil
        statusMessage = "Tap a rack tile, then tap the board to place your first word on ★"
        setupBoard()
        setupTileBag()
        rack.removeAll()
        drawTiles(count: 7)
    }

    // MARK: Board & Bag Setup

    private func setupBoard() {
        var newGrid: [[BoardCell]] = []
        for r in 0..<boardSize {
            var rowCells: [BoardCell] = []
            for c in 0..<boardSize {
                rowCells.append(BoardCell(row: r, col: c, bonus: bonusFor(row: r, col: c)))
            }
            newGrid.append(rowCells)
        }
        grid = newGrid
    }

    private func bonusFor(row: Int, col: Int) -> BonusType {
        if row == centerIndex && col == centerIndex {
            return .centerStar
        }

        let pos = GridPos(row: row, col: col)

        let tripleWordPositions: Set<GridPos> = [
            GridPos(row: 0, col: 0), GridPos(row: 0, col: 5), GridPos(row: 0, col: 10),
            GridPos(row: 5, col: 0), GridPos(row: 5, col: 10),
            GridPos(row: 10, col: 0), GridPos(row: 10, col: 5), GridPos(row: 10, col: 10)
        ]
        if tripleWordPositions.contains(pos) { return .tripleWord }

        let doubleWordPositions: Set<GridPos> = [
            GridPos(row: 1, col: 1), GridPos(row: 2, col: 2),
            GridPos(row: 1, col: 9), GridPos(row: 2, col: 8),
            GridPos(row: 9, col: 1), GridPos(row: 8, col: 2),
            GridPos(row: 9, col: 9), GridPos(row: 8, col: 8)
        ]
        if doubleWordPositions.contains(pos) { return .doubleWord }

        let tripleLetterPositions: Set<GridPos> = [
            GridPos(row: 1, col: 5), GridPos(row: 5, col: 1),
            GridPos(row: 5, col: 9), GridPos(row: 9, col: 5),
            GridPos(row: 3, col: 3), GridPos(row: 3, col: 7),
            GridPos(row: 7, col: 3), GridPos(row: 7, col: 7)
        ]
        if tripleLetterPositions.contains(pos) { return .tripleLetter }

        let doubleLetterPositions: Set<GridPos> = [
            GridPos(row: 0, col: 2), GridPos(row: 0, col: 8),
            GridPos(row: 2, col: 0), GridPos(row: 8, col: 0),
            GridPos(row: 2, col: 10), GridPos(row: 8, col: 10),
            GridPos(row: 10, col: 2), GridPos(row: 10, col: 8),
            GridPos(row: 2, col: 4), GridPos(row: 2, col: 6),
            GridPos(row: 4, col: 2), GridPos(row: 6, col: 2),
            GridPos(row: 4, col: 8), GridPos(row: 6, col: 8),
            GridPos(row: 8, col: 4), GridPos(row: 8, col: 6),
            GridPos(row: 4, col: 4), GridPos(row: 4, col: 6),
            GridPos(row: 6, col: 4), GridPos(row: 6, col: 6)
        ]
        if doubleLetterPositions.contains(pos) { return .doubleLetter }

        return .none
    }

    private func setupTileBag() {
        let specs: [TileSpec] = [
            TileSpec(letter: "A", points: 1, count: 9),
            TileSpec(letter: "B", points: 3, count: 2),
            TileSpec(letter: "C", points: 3, count: 2),
            TileSpec(letter: "D", points: 2, count: 4),
            TileSpec(letter: "E", points: 1, count: 12),
            TileSpec(letter: "F", points: 4, count: 2),
            TileSpec(letter: "G", points: 2, count: 3),
            TileSpec(letter: "H", points: 4, count: 2),
            TileSpec(letter: "I", points: 1, count: 9),
            TileSpec(letter: "J", points: 8, count: 1),
            TileSpec(letter: "K", points: 5, count: 1),
            TileSpec(letter: "L", points: 1, count: 4),
            TileSpec(letter: "M", points: 3, count: 2),
            TileSpec(letter: "N", points: 1, count: 6),
            TileSpec(letter: "O", points: 1, count: 8),
            TileSpec(letter: "P", points: 3, count: 2),
            TileSpec(letter: "Q", points: 10, count: 1),
            TileSpec(letter: "R", points: 1, count: 6),
            TileSpec(letter: "S", points: 1, count: 4),
            TileSpec(letter: "T", points: 1, count: 6),
            TileSpec(letter: "U", points: 1, count: 4),
            TileSpec(letter: "V", points: 4, count: 2),
            TileSpec(letter: "W", points: 4, count: 2),
            TileSpec(letter: "X", points: 8, count: 1),
            TileSpec(letter: "Y", points: 4, count: 2),
            TileSpec(letter: "Z", points: 10, count: 1)
        ]

        var bag: [Tile] = []
        for spec in specs {
            for _ in 0..<spec.count {
                bag.append(Tile(letter: spec.letter, points: spec.points))
            }
        }
        tileBag = bag.shuffled()
    }

    private func drawTiles(count: Int) {
        let drawCount = min(count, tileBag.count)
        guard drawCount > 0 else { return }
        rack.append(contentsOf: tileBag.prefix(drawCount))
        tileBag.removeFirst(drawCount)
        if selectedRackTileID == nil {
            selectedRackTileID = rack.first?.id
        }
    }

    // MARK: Player Controls

    func selectRackTile(_ tile: Tile) {
        if selectedRackTileID == tile.id {
            selectedRackTileID = nil
        } else {
            selectedRackTileID = tile.id
        }
    }

    func tapBoardCell(row: Int, col: Int) {
        guard row >= 0, row < grid.count, col >= 0, col < grid[row].count else { return }
        let cell = grid[row][col]

        if let placedTile = cell.tile, !cell.isLocked {
            grid[row][col].tile = nil
            rack.append(placedTile)
            selectedRackTileID = placedTile.id
            return
        }

        guard cell.tile == nil,
              let selectedID = selectedRackTileID,
              let rackIndex = rack.firstIndex(where: { $0.id == selectedID }) else {
            return
        }

        let tileToPlace = rack.remove(at: rackIndex)
        grid[row][col].tile = tileToPlace
        selectedRackTileID = rack.first?.id
    }

    func recallTiles() {
        for r in 0..<grid.count {
            for c in 0..<grid[r].count {
                if let tile = grid[r][c].tile, !grid[r][c].isLocked {
                    rack.append(tile)
                    grid[r][c].tile = nil
                }
            }
        }
        selectedRackTileID = rack.first?.id
        statusMessage = "Returned unplayed tiles to your rack."
    }

    func shuffleRack() {
        rack.shuffle()
    }

    func swapRackTiles() {
        recallTiles()
        guard !tileBag.isEmpty else {
            statusMessage = "No tiles left in the bag to swap."
            return
        }
        let oldRack = rack
        rack.removeAll()
        tileBag.append(contentsOf: oldRack)
        tileBag.shuffle()
        drawTiles(count: min(7, tileBag.count))
        statusMessage = "Swapped your rack for new tiles."
    }

    // MARK: Turn Validation & Scoring

    func submitTurn() {
        var placedPositions: [GridPos] = []
        var hasLockedTiles = false

        for r in 0..<grid.count {
            for c in 0..<grid[r].count {
                if grid[r][c].isLocked {
                    hasLockedTiles = true
                } else if grid[r][c].tile != nil {
                    placedPositions.append(GridPos(row: r, col: c))
                }
            }
        }

        guard !placedPositions.isEmpty else {
            statusMessage = "Place at least one tile on the board first."
            return
        }

        if !hasLockedTiles {
            let coversCenter = placedPositions.contains(GridPos(row: centerIndex, col: centerIndex))
            guard coversCenter else {
                statusMessage = "Your first word must cover the center ★ square."
                return
            }
            guard placedPositions.count >= 2 else {
                statusMessage = "Your first word must be at least 2 letters long."
                return
            }
        }

        let rows = Set(placedPositions.map { $0.row })
        let cols = Set(placedPositions.map { $0.col })
        let sameRow = rows.count == 1
        let sameCol = cols.count == 1

        guard sameRow || sameCol else {
            statusMessage = "All tiles placed in a turn must be in a single row or column."
            return
        }

        if sameRow, let r = rows.first {
            let minCol = placedPositions.map { $0.col }.min() ?? 0
            let maxCol = placedPositions.map { $0.col }.max() ?? 0
            for c in minCol...maxCol {
                if grid[r][c].tile == nil {
                    statusMessage = "Tiles in a word cannot have empty spaces between them."
                    return
                }
            }
        } else if sameCol, let c = cols.first {
            let minRow = placedPositions.map { $0.row }.min() ?? 0
            let maxRow = placedPositions.map { $0.row }.max() ?? 0
            for r in minRow...maxRow {
                if grid[r][c].tile == nil {
                    statusMessage = "Tiles in a word cannot have empty spaces between them."
                    return
                }
            }
        }

        if hasLockedTiles {
            let touchesExisting = placedPositions.contains { pos in
                let neighbors = [
                    GridPos(row: pos.row - 1, col: pos.col),
                    GridPos(row: pos.row + 1, col: pos.col),
                    GridPos(row: pos.row, col: pos.col - 1),
                    GridPos(row: pos.row, col: pos.col + 1)
                ]
                return neighbors.contains { n in
                    n.row >= 0 && n.row < boardSize && n.col >= 0 && n.col < boardSize && grid[n.row][n.col].isLocked
                }
            }
            guard touchesExisting else {
                statusMessage = "New tiles must connect to an existing word on the board."
                return
            }
        }

        var scoredWordsByKey: [String: ScoredWord] = [:]
        for pos in placedPositions {
            if let horizontalWord = extractWord(row: pos.row, col: pos.col, horizontal: true) {
                scoredWordsByKey[horizontalWord.key] = horizontalWord
            }
            if let verticalWord = extractWord(row: pos.row, col: pos.col, horizontal: false) {
                scoredWordsByKey[verticalWord.key] = verticalWord
            }
        }

        let formedWords = Array(scoredWordsByKey.values)
        guard !formedWords.isEmpty else {
            statusMessage = "Words must be at least 2 letters long."
            return
        }

        for item in formedWords {
            if !isValidWord(item.word) {
                statusMessage = "'\(item.word)' is not recognized in the dictionary."
                return
            }
        }

        var turnPoints = formedWords.reduce(0) { $0 + $1.score }
        if placedPositions.count == 7 {
            turnPoints += 50
        }

        for pos in placedPositions {
            grid[pos.row][pos.col].isLocked = true
        }

        let wordStrings = formedWords.map { $0.word }
        playerScore += turnPoints
        moveHistory.insert(MoveRecord(player: "You", words: wordStrings, points: turnPoints), at: 0)
        drawTiles(count: 7 - rack.count)
        selectedRackTileID = rack.first?.id

        statusMessage = "Scored +\(turnPoints) pts for \(wordStrings.joined(separator: ", "))!"
    }

    private func extractWord(row: Int, col: Int, horizontal: Bool) -> ScoredWord? {
        var startR = row
        var startC = col
        var endR = row
        var endC = col

        if horizontal {
            while startC > 0 && grid[row][startC - 1].tile != nil { startC -= 1 }
            while endC < boardSize - 1 && grid[row][endC + 1].tile != nil { endC += 1 }
            guard endC - startC + 1 >= 2 else { return nil }
        } else {
            while startR > 0 && grid[startR - 1][col].tile != nil { startR -= 1 }
            while endR < boardSize - 1 && grid[endR + 1][col].tile != nil { endR += 1 }
            guard endR - startR + 1 >= 2 else { return nil }
        }

        var builtWord = ""
        var baseScore = 0
        var wordMultiplier = 1

        let length = horizontal ? (endC - startC + 1) : (endR - startR + 1)
        for offset in 0..<length {
            let r = horizontal ? row : (startR + offset)
            let c = horizontal ? (startC + offset) : col
            let cell = grid[r][c]
            guard let tile = cell.tile else { continue }

            builtWord += tile.letter
            var letterPoints = tile.points

            if !cell.isLocked {
                switch cell.bonus {
                case .doubleLetter:
                    letterPoints *= 2
                case .tripleLetter:
                    letterPoints *= 3
                case .doubleWord, .centerStar:
                    wordMultiplier *= 2
                case .tripleWord:
                    wordMultiplier *= 3
                case .none:
                    break
                }
            }
            baseScore += letterPoints
        }

        let key = "\(horizontal ? "H" : "V")-\(startR)-\(startC)-\(endR)-\(endC)"
        return ScoredWord(key: key, word: builtWord, score: baseScore * wordMultiplier)
    }

    private func isValidWord(_ word: String) -> Bool {
        let lower = word.lowercased()
        guard lower.count >= 2 else { return false }

        #if canImport(UIKit)
        let checker = UITextChecker()
        let range = NSRange(location: 0, length: lower.utf16.count)
        let misspelled = checker.rangeOfMisspelledWord(
            in: lower,
            range: range,
            startingAt: 0,
            wrap: false,
            language: "en_US"
        )
        return misspelled.location == NSNotFound
        #elseif canImport(AppKit)
        let checker = NSSpellChecker.shared
        let range = checker.checkSpelling(
            of: lower,
            startingAt: 0,
            language: "en_US",
            wrap: false,
            inSpellDocumentWithTag: 0,
            wordCount: nil
        )
        return range.location == NSNotFound
        #else
        return true
        #endif
    }
}

// MARK: - SwiftUI Views

struct ContentView: View {
    @StateObject private var game = WordGameViewModel()

    var body: some View {
        VStack(spacing: 12) {
            // Top Score Bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Solo Scrabble")
                        .font(.title2.bold())
                    Text("Tiles in Bag: \(game.tileBag.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SCORE")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text("\(game.playerScore)")
                        .font(.title.bold().monospacedDigit())
                }
            }
            .padding(.horizontal)

            // Status Message
            Text(game.statusMessage)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(8)
                .padding(.horizontal)

            // Board Grid
            GeometryReader { geo in
                let rawSide = min(geo.size.width, geo.size.height)
                let side = max(rawSide, 220)
                let spacing: CGFloat = 2
                let cellSize = max(16, (side - spacing * CGFloat(game.boardSize + 1)) / CGFloat(game.boardSize))

                if !game.grid.isEmpty {
                    VStack(spacing: spacing) {
                        ForEach(0..<game.boardSize, id: \.self) { r in
                            HStack(spacing: spacing) {
                                ForEach(0..<game.boardSize, id: \.self) { c in
                                    BoardCellView(cell: game.grid[r][c], size: cellSize)
                                        .onTapGesture {
                                            game.tapBoardCell(row: r, col: c)
                                        }
                                }
                            }
                        }
                    }
                    .padding(spacing)
                    .background(Color(red: 0.22, green: 0.28, blue: 0.24))
                    .cornerRadius(8)
                    .frame(width: side, height: side)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.horizontal, 8)

            // Tile Rack
            HStack(spacing: 6) {
                ForEach(game.rack) { tile in
                    RackTileView(
                        tile: tile,
                        isSelected: game.selectedRackTileID == tile.id
                    )
                    .onTapGesture {
                        game.selectRackTile(tile)
                    }
                }
            }
            .frame(height: 54)
            .padding(.horizontal, 10)
            .background(Color(red: 0.45, green: 0.30, blue: 0.18).opacity(0.22))
            .cornerRadius(10)

            // Controls
            HStack(spacing: 8) {
                Button(action: game.submitTurn) {
                    Label("Play", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button("Recall", action: game.recallTiles)
                    .buttonStyle(.bordered)

                Button("Shuffle", action: game.shuffleRack)
                    .buttonStyle(.bordered)

                Button("Swap", action: game.swapRackTiles)
                    .buttonStyle(.bordered)

                Button("Reset", action: game.startNewGame)
                    .buttonStyle(.bordered)
                    .tint(.red)
            }
            .padding(.horizontal)

            // Move History
            if !game.moveHistory.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(game.moveHistory) { move in
                            Text("\(move.words.joined(separator: " + ")) (+\(move.points))")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 28)
            }
        }
        .padding(.vertical, 8)
        .frame(minWidth: 360, minHeight: 620)
    }
}

struct BoardCellView: View {
    let cell: BoardCell
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(cell.bonus.fillColor)

            if let tile = cell.tile {
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        cell.isLocked
                        ? Color(red: 0.94, green: 0.85, blue: 0.65)
                        : Color(red: 1.0, green: 0.94, blue: 0.74)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(
                                cell.isLocked ? Color.brown.opacity(0.6) : Color.orange,
                                lineWidth: cell.isLocked ? 1 : 2
                            )
                    )

                VStack(spacing: -2) {
                    Text(tile.letter)
                        .font(.system(size: size * 0.50, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    Text("\(tile.points)")
                        .font(.system(size: size * 0.24, weight: .semibold, design: .rounded))
                        .foregroundColor(.black.opacity(0.75))
                }
            } else {
                Text(cell.bonus.label)
                    .font(.system(size: size * 0.32, weight: .bold))
                    .foregroundColor(
                        cell.bonus == .tripleWord || cell.bonus == .tripleLetter
                        ? .white
                        : .black.opacity(0.7)
                    )
            }
        }
        .frame(width: size, height: size)
    }
}

struct RackTileView: View {
    let tile: Tile
    let isSelected: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(red: 0.96, green: 0.87, blue: 0.68))
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.blue : Color.brown.opacity(0.5), lineWidth: isSelected ? 3 : 1)
                )

            Text(tile.letter)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text("\(tile.points)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.black.opacity(0.75))
                .padding(3)
        }
        .frame(width: 42, height: 46)
        .offset(y: isSelected ? -6 : 0)
        .animation(.spring(response: 0.2), value: isSelected)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
