import { ImageResponse } from 'next/og'
import { readFile } from 'fs/promises'
import { join } from 'path'

export const alt = 'infatium — верни контроль над информацией'
export const size = {
  width: 1200,
  height: 630,
}
export const contentType = 'image/png'

export default async function Image() {
  const jellyfishData = await readFile(join(process.cwd(), 'public', 'jellyfish.png'))

  return new ImageResponse(
    (
      <div
        style={{
          height: '100%',
          width: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          background: 'linear-gradient(135deg, #0a0a0a 0%, #1a1a2e 50%, #0a0a0a 100%)',
        }}
      >
        <img
          alt=""
          src={`data:image/png;base64,${jellyfishData.toString('base64')}`}
          width={500}
          height={500}
          style={{ filter: 'invert(1)' }}
        />
      </div>
    ),
    {
      ...size,
    }
  )
}
