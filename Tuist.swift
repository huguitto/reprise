import ProjectDescription

// El .xcodeproj se genera desde este manifiesto y NO se versiona.
// Es lo que permite que varios agentes trabajen a la vez sin pelearse por el
// project.pbxproj, que es un unico fichero imposible de fusionar a mano.
let tuist = Tuist()
