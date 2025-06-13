import { Block } from 'payload'

export const textBlock: Block = {
  slug: 'text-block',
  fields: [
    {
      name: 'text',
      type: 'text',
      label: 'Text',
      required: true,
    },
  ],
}
