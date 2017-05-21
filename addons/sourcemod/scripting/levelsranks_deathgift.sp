#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <lvl_ranks>

#define PLUGIN_NAME "Levels Ranks"
#define PLUGIN_AUTHOR "RoadSide Romeo"

#define EngineGameCSGO 1
#define EngineGameCSS 2
#define EngineGameTF2 3

int		g_iCvarChance,
		g_iCvarLifeTime,
		g_iCvarValue,
		g_iEngineGame;

public Plugin myinfo = {name = "[LR] Module - DeathGift", author = PLUGIN_AUTHOR, version = PLUGIN_VERSION}
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	switch(GetEngineVersion())
	{
		case Engine_CSGO: g_iEngineGame = EngineGameCSGO;
		case Engine_CSS: g_iEngineGame = EngineGameCSS;
		case Engine_TF2: g_iEngineGame = EngineGameTF2;
		default: SetFailState("[%s DeathGift] Плагин работает только в CS:GO, CS:S или TF2", PLUGIN_NAME);
	}
}

public void OnPluginStart()
{
	HookEvent("player_death", PlayerDeath);
	LoadTranslations("levels_ranks_deathgift.phrases");
}

public void OnMapStart()
{
	char sPath[PLATFORM_MAX_PATH];
	PrecacheModel("models/items/cs_gift-34.mdl", true);
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/deathgift.ini");
	KeyValues hLR_DeathGift = new KeyValues("LR_DeathGift");

	if(!hLR_DeathGift.ImportFromFile(sPath) || !hLR_DeathGift.GotoFirstSubKey())
	{
		SetFailState("[%s DeathGift] : фатальная ошибка - файл не найден (%s)", PLUGIN_NAME, sPath);
	}

	hLR_DeathGift.Rewind();

	if(hLR_DeathGift.JumpToKey("Settings"))
	{
		switch(LR_TypeStatistics())
		{
			case 2: g_iCvarChance = -1;
			case 3: g_iCvarChance = -1;
			case 4: g_iCvarChance = -1;
			default: g_iCvarChance = hLR_DeathGift.GetNum("lr_gifts_chance", 40);
		}
		g_iCvarLifeTime = hLR_DeathGift.GetNum("lr_gifts_lifetime", 10);
		g_iCvarValue = hLR_DeathGift.GetNum("lr_gifts_value", 1);
	}
	else SetFailState("[%s DeathGift] : фатальная ошибка - секция Settings не найдена", PLUGIN_NAME);
	delete hLR_DeathGift;
}

public void OnConfigsExecuted()
{
	AddFileToDownloadsTable("materials/models/items/cs_gift-34.vmt");
	AddFileToDownloadsTable("materials/models/items/cs_gift-34.vtf");
	AddFileToDownloadsTable("models/items/cs_gift-34.mdl");
	AddFileToDownloadsTable("models/items/cs_gift-34.phy");
	AddFileToDownloadsTable("models/items/cs_gift-34.vvd");
	AddFileToDownloadsTable("models/items/cs_gift-34.dx80.vtx");
	AddFileToDownloadsTable("models/items/cs_gift-34.dx90.vtx");
	AddFileToDownloadsTable("models/items/cs_gift-34.sw.vtx");
	AddFileToDownloadsTable("sound/levels_ranks/deathgift_drop.mp3");
	AddFileToDownloadsTable("sound/levels_ranks/deathgift_pickup.mp3");
	LR_PrecacheSound();
}

public void PlayerDeath(Handle event, char[] name, bool dontBroadcast)
{
	if(g_iCvarChance > 0 && g_iCvarLifeTime > 0 && g_iCvarValue > 0)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));

		if(GetRandomInt(1, 100) <= g_iCvarChance)
		{
			float pos[3];
			GetClientAbsOrigin(client, pos);
		
			pos[2]-=50.0;
			Stock_SpawnGift(pos, "models/items/cs_gift-34.mdl");
		}
	}
}

stock int Stock_SpawnGift(float position[3], const char[] model)
{
	int m_iGift;

	if((m_iGift = CreateEntityByName("prop_physics_override")) != -1)
	{
		char targetname[16], m_szModule[PLATFORM_MAX_PATH];

		FormatEx(targetname, sizeof(targetname), "gift_%i", m_iGift);

		DispatchKeyValue(m_iGift, "model", model);
		DispatchKeyValue(m_iGift, "physicsmode", "2");
		DispatchKeyValue(m_iGift, "massScale", "1.0");
		DispatchKeyValue(m_iGift, "targetname", targetname);
		DispatchSpawn(m_iGift);
		
		SetEntProp(m_iGift, Prop_Send, "m_usSolidFlags", 8);
		SetEntProp(m_iGift, Prop_Send, "m_CollisionGroup", 1);

		FormatEx(m_szModule, sizeof(m_szModule), "OnUser1 !self:kill::%i:-1", g_iCvarLifeTime);
		SetVariantString(m_szModule);
		AcceptEntityInput(m_iGift, "AddOutput");
		AcceptEntityInput(m_iGift, "FireUser1");

		DispatchKeyValueVector(m_iGift, "origin", position);
		
		int m_iRotator = CreateEntityByName("func_rotating");
		DispatchKeyValueVector(m_iRotator, "origin", position);
		DispatchKeyValue(m_iRotator, "targetname", targetname);
		DispatchKeyValue(m_iRotator, "maxspeed", "200");
		DispatchKeyValue(m_iRotator, "friction", "0");
		DispatchKeyValue(m_iRotator, "dmg", "0");
		DispatchKeyValue(m_iRotator, "solid", "0");
		DispatchKeyValue(m_iRotator, "spawnflags", "64");
		DispatchSpawn(m_iRotator);

		SetVariantString("!activator");
		AcceptEntityInput(m_iGift, "SetParent", m_iRotator, m_iRotator);
		AcceptEntityInput(m_iRotator, "Start");

		SetVariantString(m_szModule);
		AcceptEntityInput(m_iRotator, "AddOutput");
		AcceptEntityInput(m_iRotator, "FireUser1");

		SetEntPropEnt(m_iGift, Prop_Send, "m_hEffectEntity", m_iRotator);
		SDKHook(m_iGift, SDKHook_StartTouch, OnStartTouch);
	}

	LR_EmitSoundAll("levels_ranks/deathgift_drop.mp3");
	return m_iGift;
}

public void OnStartTouch(int m_iGift, int client)
{
	if(!IsValidClient(client))
		return;

	int m_iRotator = GetEntPropEnt(m_iGift, Prop_Send, "m_hEffectEntity");
	if(m_iRotator && IsValidEdict(m_iRotator))
	{
		AcceptEntityInput(m_iRotator, "Kill");
	}
	
	LR_EmitSoundAll("levels_ranks/deathgift_pickup.mp3");
	LR_ChangeClientValue(client, g_iCvarValue);
	RemoveEntity(m_iGift);

	int iValue = LR_GetClientValue(client);
	switch(LR_TypeStatistics())
	{
		case 0: LR_PrintToChat(client, "%t", "TouchGiftExp", iValue, g_iCvarValue);
		case 1: LR_PrintToChat(client, "%t", "TouchGiftTime", iValue / 3600, iValue / 60 % 60, iValue % 60, g_iCvarValue);
	}
}

public void RemoveEntity(int m_iGift)
{
	if(IsValidEntity(m_iGift))
	{
		AcceptEntityInput(m_iGift, "Kill");
	}
	SDKUnhook(m_iGift, SDKHook_StartTouch, OnStartTouch);
}

void LR_PrecacheSound()
{
	switch(g_iEngineGame)
	{
		case EngineGameCSGO:
		{
			AddToStringTable(FindStringTable("soundprecache"), "*levels_ranks/deathgift_drop.mp3");
			AddToStringTable(FindStringTable("soundprecache"), "*levels_ranks/deathgift_pickup.mp3");
		}

		case EngineGameCSS, EngineGameTF2:
		{
			PrecacheSound("levels_ranks/deathgift_drop.mp3");
			PrecacheSound("levels_ranks/deathgift_pickup.mp3");
		}
	}
}

void LR_EmitSoundAll(char[] sPath)
{
	char sBuffer[256];
	switch(g_iEngineGame)
	{
		case EngineGameCSGO: FormatEx(sBuffer, sizeof(sBuffer), "*%s", sPath);
		case EngineGameCSS, EngineGameTF2: FormatEx(sBuffer, sizeof(sBuffer), sPath);
	}
	EmitSoundToAll(sBuffer, SOUND_FROM_WORLD, SNDCHAN_ITEM);
}