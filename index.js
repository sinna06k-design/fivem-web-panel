const { Client, GatewayIntentBits, EmbedBuilder, REST, Routes } = require('discord.js');
const express = require('express');
const axios = require('axios');

// Configuration
const DISCORD_TOKEN = 'MTUxOTc0Nzk2Mjk3MDk2NDEwOQ.GPIdfr.iju4a8OlbqmiSp94Dyrs2KgyUeLGeuAc1tV8mE'; // Replace with actual token
const CLIENT_ID = '1519747962970964109'; // Replace with actual client ID
const GUILD_ID = '1338800907537879040'; // The Discord Server ID
const LOG_CHANNEL_ID = '1518161025067913286'; // The Channel to send alerts to
const FIVEM_SERVER_URL = 'http://localhost:30120/api/botcommand';
const SECRET_TOKEN = 'NyxSecretToken2026';
const PORT = process.env.PORT || 3000;

// Initialize Discord Client
const client = new Client({ intents: [GatewayIntentBits.Guilds, GatewayIntentBits.GuildMessages] });

// Initialize Express for receiving webhooks from AI/FiveM
const app = express();
app.use(express.json());

// Express Route for AI Alerts
app.post('/api/ai-alert', async (req, res) => {
    const { secret, playerId, playerName, reason, confidence, telemetry } = req.body;

    if (secret !== SECRET_TOKEN) {
        return res.status(401).json({ error: 'Unauthorized' });
    }

    try {
        const channel = await client.channels.fetch(LOG_CHANNEL_ID);
        if (channel) {
            const embed = new EmbedBuilder()
                .setTitle('🚨 AI AntiCheat Alert 🚨')
                .setColor('#FF0000')
                .addFields(
                    { name: 'Player Name', value: playerName || 'Unknown', inline: true },
                    { name: 'Player ID', value: String(playerId), inline: true },
                    { name: 'AI Confidence', value: `${confidence}%`, inline: true },
                    { name: 'Detection Reason', value: reason || 'Unknown' },
                    { name: 'Telemetry (Pitch/Yaw/Dist)', value: `${telemetry.pitchDelta} / ${telemetry.yawDelta} / ${telemetry.distance}` }
                )
                .setTimestamp();

            await channel.send({ embeds: [embed] });
        }
        res.status(200).json({ success: true });
    } catch (err) {
        console.error('Failed to send Discord alert:', err);
        res.status(500).json({ error: 'Internal Server Error' });
    }
});

// Setup Slash Commands
const commands = [
    {
        name: 'ban',
        description: 'Ban a player from the FiveM server',
        options: [
            {
                name: 'playerid',
                type: 4, // Integer
                description: 'The ID of the player to ban',
                required: true,
            },
            {
                name: 'reason',
                type: 3, // String
                description: 'The reason for the ban',
                required: false,
            }
        ]
    },
    {
        name: 'ai-status',
        description: 'Check the status of the AI AntiCheat backend'
    }
];

const rest = new REST({ version: '10' }).setToken(DISCORD_TOKEN);

client.once('ready', async () => {
    console.log(`[Bot] Logged in as ${client.user.tag}`);

    try {
        console.log('Started refreshing application (/) commands.');
        await rest.put(
            Routes.applicationGuildCommands(CLIENT_ID, GUILD_ID),
            { body: commands },
        );
        console.log('Successfully reloaded application (/) commands.');
    } catch (error) {
        console.error(error);
    }
});

client.on('interactionCreate', async interaction => {
    if (!interaction.isChatInputCommand()) return;

    if (interaction.commandName === 'ban') {
        const playerId = interaction.options.getInteger('playerid');
        const reason = interaction.options.getString('reason') || 'Banned via Discord';

        await interaction.deferReply();

        try {
            const response = await axios.post(FIVEM_SERVER_URL, {
                secret: SECRET_TOKEN,
                action: 'ban',
                playerId: playerId,
                reason: reason
            });

            if (response.data.status === 'success') {
                await interaction.editReply(`✅ Successfully banned Player ID ${playerId}. Reason: ${reason}`);
            } else {
                await interaction.editReply(`❌ Failed to ban: ${response.data.message}`);
            }
        } catch (err) {
            console.error(err);
            await interaction.editReply(`❌ Error contacting the FiveM Server. Is it online?`);
        }
    } else if (interaction.commandName === 'ai-status') {
        // Here you would ping the python backend API. For now, we simulate it.
        await interaction.reply('🟢 AI Backend is ONLINE and actively monitoring telemetry.');
    }
});

// Start the Express Server
app.listen(PORT, () => {
    console.log(`[Express] Webhook listener running on port ${PORT}`);
});

// Login Discord Bot
client.login(DISCORD_TOKEN);
