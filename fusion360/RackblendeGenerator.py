import adsk.core
import adsk.fusion
import adsk.cam
import traceback

WIDTH_MM = 482.6
U_HEIGHT_MM = 44.45
THICKNESS_MM = 6.0
CHAMFER_MM = 1.2

handlers = []


def run(context):
    ui = None
    try:
        app = adsk.core.Application.get()
        ui = app.userInterface

        cmdDef = ui.commandDefinitions.itemById('RackPanelFinalFixV6')
        if not cmdDef:
            cmdDef = ui.commandDefinitions.addButtonDefinition(
                'RackPanelFinalFixV6',
                'Rackblende Fase v6',
                'Sichere Flächenerkennung'
            )

        onCommandCreated = RackPanelCommandCreatedHandler()
        cmdDef.commandCreated.add(onCommandCreated)
        handlers.append(onCommandCreated)

        cmdDef.execute()
        adsk.autoTerminate(False)

    except:
        if ui:
            ui.messageBox(traceback.format_exc())


class RackPanelCommandCreatedHandler(adsk.core.CommandCreatedEventHandler):
    def notify(self, args):
        cmd = args.command
        inputs = cmd.commandInputs

        radio = inputs.addRadioButtonGroupCommandInput('he_select', 'Höheneinheiten (HE)')
        for i in range(1, 6):
            height_mm = U_HEIGHT_MM * i
            radio.listItems.add(f'{i} HE ({height_mm:.2f} mm)', i == 1)

        onExecute = RackPanelExecuteHandler()
        cmd.execute.add(onExecute)
        handlers.append(onExecute)


class RackPanelExecuteHandler(adsk.core.CommandEventHandler):
    def notify(self, args):
        try:
            app = adsk.core.Application.get()
            design = adsk.fusion.Design.cast(app.activeProduct)
            rootComp = design.rootComponent

            he_input = args.command.commandInputs.itemById('he_select')
            he_val = 1
            for i in range(he_input.listItems.count):
                if he_input.listItems.item(i).isSelected:
                    he_val = i + 1

            w = WIDTH_MM / 10
            h = (U_HEIGHT_MM * he_val) / 10
            t = THICKNESS_MM / 10
            fase = CHAMFER_MM / 10

            # 1. Skizze & Rechteck (Voll bestimmt)
            sketch = rootComp.sketches.add(rootComp.xZConstructionPlane)
            sketch.name = f'{he_val}HE-Grundplatte'
            lines = sketch.sketchCurves.sketchLines
            constraints = sketch.geometricConstraints

            p1 = adsk.core.Point3D.create(-w / 2, -h / 2, 0)
            p2 = adsk.core.Point3D.create(w / 2, -h / 2, 0)
            p3 = adsk.core.Point3D.create(w / 2, h / 2, 0)
            p4 = adsk.core.Point3D.create(-w / 2, h / 2, 0)

            l1 = lines.addByTwoPoints(p1, p2)
            l2 = lines.addByTwoPoints(l1.endSketchPoint, p3)
            l3 = lines.addByTwoPoints(l2.endSketchPoint, p4)
            l4 = lines.addByTwoPoints(l3.endSketchPoint, l1.startSketchPoint)

            constraints.addHorizontal(l1)
            constraints.addHorizontal(l3)
            constraints.addVertical(l2)
            constraints.addVertical(l4)

            diag1 = lines.addByTwoPoints(l1.startSketchPoint, l3.startSketchPoint)
            diag1.isConstruction = True
            constraints.addMidPoint(sketch.originPoint, diag1)

            dims = sketch.sketchDimensions
            dims.addDistanceDimension(
                l1.startSketchPoint,
                l1.endSketchPoint,
                adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                adsk.core.Point3D.create(0, -h / 2 - 1, 0)
            )
            dims.addDistanceDimension(
                l2.startSketchPoint,
                l2.endSketchPoint,
                adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                adsk.core.Point3D.create(w / 2 + 1, 0, 0)
            )

            # Konstruktionslinien alle 44,45 mm (bei 2-5 HE)
            if he_val > 1:
                u_height = U_HEIGHT_MM / 10  # In cm für Fusion
                for i in range(1, he_val):
                    y_pos = -h / 2 + (u_height * i)
                    constr_line = lines.addByTwoPoints(
                        adsk.core.Point3D.create(-w / 2, y_pos, 0),
                        adsk.core.Point3D.create(w / 2, y_pos, 0)
                    )
                    constr_line.isConstruction = True
                    constraints.addHorizontal(constr_line)
                    # An linker Seite (l4) fixieren
                    constraints.addCoincident(constr_line.startSketchPoint, l4)
                    # An rechter Seite (l2) fixieren
                    constraints.addCoincident(constr_line.endSketchPoint, l2)
                    # Abstand von unten bemaßen
                    dims.addDistanceDimension(
                        l1.startSketchPoint,
                        constr_line.startSketchPoint,
                        adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                        adsk.core.Point3D.create(-w / 2 - 1, y_pos / 2, 0)
                    )

            # 2. Extrusion
            prof = sketch.profiles.item(0)
            extrudes = rootComp.features.extrudeFeatures
            extInput = extrudes.createInput(
                prof,
                adsk.fusion.FeatureOperations.NewBodyFeatureOperation
            )
            extInput.setDistanceExtent(False, adsk.core.ValueInput.createByReal(t))
            extFeature = extrudes.add(extInput)
            body = extFeature.bodies.item(0)
            body.name = f'{he_val}HE-Grundplatte'

            # FASE auf Vorderseite (Startfläche der Extrusion)
            startFace = extFeature.startFaces.item(0)
            front_edges = adsk.core.ObjectCollection.create()
            for edge in startFace.edges:
                front_edges.add(edge)

            if front_edges.count > 0:
                chamfers = rootComp.features.chamferFeatures
                chamferInput = chamfers.createInput(front_edges, True)
                chamferInput.setToEqualDistance(adsk.core.ValueInput.createByReal(fase))
                chamfers.add(chamferInput)

            # 2b. Zweite Skizze: Innenraum (auf Rückseite der Grundplatte)
            INNER_WIDTH_MM = 446.0
            w_inner = INNER_WIDTH_MM / 10

            # Offset-Ebene erstellen (parallel zur XZ-Ebene, um Dicke versetzt)
            planes = rootComp.constructionPlanes
            planeInput = planes.createInput()
            offsetValue = adsk.core.ValueInput.createByReal(t)
            planeInput.setByOffset(rootComp.xZConstructionPlane, offsetValue)
            backPlane = planes.add(planeInput)
            backPlane.name = f'{he_val}HE-Rückebene'

            sketch2 = rootComp.sketches.add(backPlane)
            sketch2.name = f'{he_val}HE-Innenraum'
            lines2 = sketch2.sketchCurves.sketchLines
            constraints2 = sketch2.geometricConstraints

            # Gleiche Orientierung wie Grundplatte
            p1_inner = adsk.core.Point3D.create(-w_inner / 2, -h / 2, 0)
            p2_inner = adsk.core.Point3D.create(w_inner / 2, -h / 2, 0)
            p3_inner = adsk.core.Point3D.create(w_inner / 2, h / 2, 0)
            p4_inner = adsk.core.Point3D.create(-w_inner / 2, h / 2, 0)

            l1_inner = lines2.addByTwoPoints(p1_inner, p2_inner)
            l2_inner = lines2.addByTwoPoints(l1_inner.endSketchPoint, p3_inner)
            l3_inner = lines2.addByTwoPoints(l2_inner.endSketchPoint, p4_inner)
            l4_inner = lines2.addByTwoPoints(l3_inner.endSketchPoint, l1_inner.startSketchPoint)

            constraints2.addHorizontal(l1_inner)
            constraints2.addHorizontal(l3_inner)
            constraints2.addVertical(l2_inner)
            constraints2.addVertical(l4_inner)

            diag_inner = lines2.addByTwoPoints(l1_inner.startSketchPoint, l3_inner.startSketchPoint)
            diag_inner.isConstruction = True
            constraints2.addMidPoint(sketch2.originPoint, diag_inner)

            dims2 = sketch2.sketchDimensions
            dims2.addDistanceDimension(
                l1_inner.startSketchPoint,
                l1_inner.endSketchPoint,
                adsk.fusion.DimensionOrientations.HorizontalDimensionOrientation,
                adsk.core.Point3D.create(0, -h / 2 - 1, 0)
            )
            dims2.addDistanceDimension(
                l2_inner.startSketchPoint,
                l2_inner.endSketchPoint,
                adsk.fusion.DimensionOrientations.VerticalDimensionOrientation,
                adsk.core.Point3D.create(w_inner / 2 + 1, 0, 0)
            )

            # Vertikale Mittellinie
            mid_line = lines2.addByTwoPoints(
                adsk.core.Point3D.create(0, -h / 2, 0),
                adsk.core.Point3D.create(0, h / 2, 0)
            )
            mid_line.isConstruction = True
            constraints2.addVertical(mid_line)
            constraints2.addCoincident(mid_line.startSketchPoint, l1_inner)
            constraints2.addCoincident(mid_line.endSketchPoint, l3_inner)
            constraints2.addMidPoint(mid_line.startSketchPoint, l1_inner)
            constraints2.addMidPoint(mid_line.endSketchPoint, l3_inner)

        except:
            print(traceback.format_exc())
