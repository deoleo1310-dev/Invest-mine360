// supabase/functions/admin-reset-password/index.ts

import { serve } from "https://deno.land/std@0.177.0/http/server.ts"
import { checkRateLimit } from "../_shared/rate-limiter.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('No authorization header')
    }

    // Extraer token y verificar usuario
    const token = authHeader.replace('Bearer ', '')
    
    // ✅ NUEVO: Verificar rate limit (10 cambios de contraseña por minuto máximo)
    const rateLimit = checkRateLimit(token, 10, 60000)
    
    if (!rateLimit.allowed) {
      return new Response(
        JSON.stringify({ 
          success: false, 
          error: 'Rate limit exceeded. Try again later.',
          remaining: rateLimit.remaining
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 429, // Too Many Requests
        }
      )
    }

    const { userId, newPassword } = await req.json()

    if (!userId || !newPassword) {
      throw new Error('userId and newPassword are required')
    }

    if (newPassword.length < 6) {
      throw new Error('Password must be at least 6 characters')
    }

    // Llamada a Admin API
    const response = await fetch(
      `${Deno.env.get('SUPABASE_URL')}/auth/v1/admin/users/${userId}`,
      {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')}`,
          'Content-Type': 'application/json',
          'apikey': Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
        },
        body: JSON.stringify({ password: newPassword })
      }
    )

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.message || 'Failed to update password')
    }

    const data = await response.json()

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Password updated successfully',
        data,
        rate_limit: {
          remaining: rateLimit.remaining
        }
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      },
    )

  } catch (error) {
    console.error('Function error:', error)
    
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      },
    )
  }
})