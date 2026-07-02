--!strict

-- Отступы Roblox core GUI (верхнее меню) и кэш для layout.



local GuiService = game:GetService("GuiService")



export type Cleanup = () -> ()



local SafeArea = {}



local _listeners: { () -> () } = {}

local _conn: RBXScriptConnection? = nil



local function notify()

	for _, listener in _listeners do

		listener()

	end

end



function SafeArea.start(): ()

	if _conn then

		return

	end

	_conn = GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(notify)

end



function SafeArea.subscribe(listener: () -> (), scope: { any }?): Cleanup

	table.insert(_listeners, listener)

	SafeArea.start()



	local function cleanup()

		local index = table.find(_listeners, listener)

		if index then

			table.remove(_listeners, index)

		end

	end



	if scope then

		table.insert(scope, cleanup)

	end



	return cleanup

end



function SafeArea.topInset(): number

	return GuiService:GetGuiInset().Y

end



function SafeArea.leftInset(): number

	return GuiService:GetGuiInset().X

end



return SafeArea

