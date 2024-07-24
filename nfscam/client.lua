local camera = {
    enabled = false,
    canRotate = false,
    lastMove = getTickCount(),
}

local sx, sy = guiGetScreenSize()

function getPointFromDistanceRotation(element, dist, angle, pitch)
    local x, y, z = getElementPosition(element)

    local a = math.rad(90 - angle)
    local p = math.rad(90 - pitch)
 
    local dx = math.cos(a) * dist
    local dy = math.sin(a) * dist
    local dz = math.cos(p) * dist
 
    return x+dx, y+dy, z+dz
end

function math.lerp(a, b, t)
    return a + (b - a) * t
end

function math.lerp_angle(a, b, t)
    local diff = (b - a + 180) % 360 - 180
    return (a + diff * t) % 360
end

local smooths = {}
function math.smooth(value, speed, name)
    if not smooths[name] then
        smooths[name] = value
    end
    smooths[name] = math.lerp(smooths[name], value, speed)
    return smooths[name]
end

function math.smooth_angle(value, speed, name)
    if not smooths[name] then
        smooths[name] = value
    end
    smooths[name] = math.lerp_angle(smooths[name], value, speed)
    return smooths[name]
end

function math.clamp(number, min, max)
	if number < min then
		return min
	elseif number > max then
		return max    
	end
	return number
end

function guessHex(byte, value)
    return "0x"..string.reverse(string.format("%0"..byte.."x", value))
end

function getVehicleHandlingFlags(vehicle, flags, byte, value)
    local hnd = getVehicleHandling(vehicle)[flags]
    local hex = guessHex(byte, value)
    return bitAnd(hnd, hex) ~= 0
end

function getVehicleMaxVelocity(vehicle)
    local maxSpeed = getVehicleHandling(vehicle).maxVelocity
    return getVehicleHandlingFlags(vehicle, "handlingFlags", 7, 1) and maxSpeed or (maxSpeed + 0.2 * maxSpeed)
end

function getVehicleHeight(vehicle)
    local x, _, z = getElementPosition(vehicle)
    local x0, _, z0, x1, _, z1 = getElementBoundingBox(vehicle)
    return getDistanceBetweenPoints2D(x+x0, z+z0, x+x0, z+z1)
end

function getVehicleLength(vehicle)
    local x, y, _ = getElementPosition(vehicle)
    local x0, y0, _, x1, y1, _ = getElementBoundingBox(vehicle)
    return getDistanceBetweenPoints2D(x+x0, y+y0, x+x0, y+y1)
end

function normalizeAngle(angle)
    angle = angle % 360
    if angle < 0 then
        angle = angle + 360
    end
    return angle
end

local rotX, rotY = 0, 0
function cursorMove(_, _, ax, ay)
    if isCursorShowing() or isMTAWindowActive() or not camera.canRotate then
        return
    end

    rotX = rotX + (ax - sx / 2) * 0.2
    rotY = rotY - (ay - sy / 2) * 0.2

    rotX = normalizeAngle(rotX)

    camera.lastMove = getTickCount()
end

function processCamera()
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if not vehicle then
        return not getCameraTarget() and setCameraTarget(localPlayer)
    end

    local accel = getAnalogControlState("accelerate")
    local brake = getAnalogControlState("brake_reverse")
    local l_left = getControlState("vehicle_look_left")
    local l_right = getControlState("vehicle_look_right")
    local l_back = (l_left and l_right) or getControlState("vehicle_look_behind")

    local height = 0.8 * getVehicleHeight(vehicle)

    local vx, vy, vz = getElementVelocity(vehicle)
    local speed = (vx*vx + vy*vy + vz*vz) ^ 0.5 * 180
    local ratio = speed / getVehicleMaxVelocity(vehicle)
    speed = ratio / math.max(getVehicleCurrentGear(vehicle), 1)

    local pitch, _, rot = getElementRotation(vehicle)

    local latG = select(3, getElementAngularVelocity(vehicle))
    latG = math.lerp(810 * latG, 650 * latG, accel - brake)
    latG = math.smooth(math.clamp(latG, -8, 8), 0.12, "latG")

    local length = 0.95 * getVehicleLength(vehicle)
    local distance = math.lerp(0.96 * -length, -length, accel - brake)
    distance = math.smooth(distance, 0.06, "distance")

    local orbit = 0
    if l_left or l_right or l_back then
        rotX = 0
        camera.canRotate = false

        if l_left then
            orbit = - 90
        end
        if l_right then
            orbit = 90
        end
        if l_back then
            orbit = 180
        end
    else
        camera.canRotate = true
        orbit = rotX
        if getTickCount() - camera.lastMove > 1500 then
            rotX = math.lerp_angle(rotX, 0, 0.1)
        end
    end

    local cx, cy, cz = getPointFromDistanceRotation(vehicle, distance - math.smooth(2 * speed, 0.06, "gear"), 360 - math.smooth_angle(rot - latG, 0.1, "lat1") + orbit, math.smooth_angle(pitch, 0.06, "pitch1"))
    local lx, ly, lz = getPointFromDistanceRotation(vehicle, 10, 360 - math.smooth_angle(rot, 0.06, "lat2") + orbit, math.smooth_angle(pitch, 0.06, "pitch2"))
        
    setCameraMatrix(cx, cy, cz + height, lx, ly, lz - 0.4, 0, 100)
end

function toggleCamera(bool)
    camera.enabled = bool
    if camera.enabled then
        addEventHandler("onClientPreRender", root, processCamera)
        addEventHandler("onClientCursorMove", root, cursorMove)
    else
        removeEventHandler("onClientPreRender", root, processCamera)
        removeEventHandler("onClientCursorMove", root, cursorMove)
        setCameraTarget(localPlayer)
    end
end

addCommandHandler("nfscam", function()
    toggleCamera(not camera.enabled)
end)