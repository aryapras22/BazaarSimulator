import Foundation

struct BazaarLayout: Decodable {
    struct Meta: Decodable {
        struct World: Decodable {
            let w: Double
            let h: Double
        }

        let name: String
        let sheet: String
        let world: World
    }

    struct Booth: Decodable, Identifiable {
        let id: String
        let type: String
        let cx: Double
        let cy: Double
        let w: Double
        let h: Double
    }

    struct Door: Decodable, Identifiable {
        let id: String
        let role: String
    }

    let meta: Meta
    let booths: [Booth]
    let doors: [Door]
    let tables: [Table]

    struct Table: Decodable {
        let cx: Double
        let cy: Double
    }
}
