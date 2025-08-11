local p="ReplicatedStorage.CommonModules.CoreUtil.BlockIndexs"
local s=game:GetService("ReplicatedStorage"):WaitForChild("DecompiledScripts")
for _,v in ipairs(s:GetChildren()) do
if v:IsA("StringValue") and v.Name==p then
setclipboard(v.Value)
break
end
end
