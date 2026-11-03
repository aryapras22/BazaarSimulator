import Foundation
import Testing
@testable import BazaarSimulator

@Suite
struct RulerScaleTests {
    @Test("At 10 points per metre labels are every 10 m, boxes 1 m with 5 m lines, and the bar is 10 m")
    func defaultZoom() {
        let scale = RulerScale(pointsPerMetre: 10)

        #expect(scale.labelStepM == 10)
        #expect(scale.gridMinorM == 1)
        #expect(scale.gridMajorM == 5)
        #expect(RulerScale.scaleBarLengthM(pointsPerMetre: 10) == 10)
    }

    @Test("At 40 points per metre labels are every 2 m and boxes 0.5 m")
    func zoomedIn() {
        let scale = RulerScale(pointsPerMetre: 40)

        #expect(scale.labelStepM == 2)
        #expect(scale.tickStepM == 0.5)
        #expect(scale.gridMinorM == 0.5)
        #expect(scale.gridMajorM == 5)
    }

    @Test("At 4 points per metre labels are every 20 m and boxes 5 m")
    func zoomedOut() {
        let scale = RulerScale(pointsPerMetre: 4)

        #expect(scale.labelStepM == 20)
        #expect(scale.gridMinorM == 5)
        #expect(scale.gridMajorM == 50)
    }

    @Test("Steps stay between 0.5 m and 100 m across the zoom range")
    func stepsStayInRange() {
        for scale in stride(from: CanvasTransform.minScale, through: CanvasTransform.maxScale, by: 1) {
            let ruler = RulerScale(pointsPerMetre: scale)
            let barM = RulerScale.scaleBarLengthM(pointsPerMetre: scale)
            let steps = [ruler.labelStepM, ruler.gridMinorM, ruler.gridMajorM, barM]

            #expect(steps.allSatisfy { (0.5...100).contains($0) })
        }
    }
}
