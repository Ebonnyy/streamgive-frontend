# ---- build ----
FROM node:22-slim AS build
WORKDIR /app

# All NEXT_PUBLIC_* vars are inlined at build time by Next.js, so they must
# be declared as ARGs here. Pass them with --build-arg on `docker build`.
ARG NEXT_PUBLIC_API_URL
ARG NEXT_PUBLIC_APP_URL
ARG NEXT_PUBLIC_SOROBAN_RPC_URL
ARG NEXT_PUBLIC_NETWORK_PASSPHRASE
ARG NEXT_PUBLIC_DONATION_VAULT_CONTRACT_ID
ARG NEXT_PUBLIC_NGO_REGISTRY_CONTRACT_ID
ARG NEXT_PUBLIC_USDC_ISSUER

ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_APP_URL=$NEXT_PUBLIC_APP_URL
ENV NEXT_PUBLIC_SOROBAN_RPC_URL=$NEXT_PUBLIC_SOROBAN_RPC_URL
ENV NEXT_PUBLIC_NETWORK_PASSPHRASE=$NEXT_PUBLIC_NETWORK_PASSPHRASE
ENV NEXT_PUBLIC_DONATION_VAULT_CONTRACT_ID=$NEXT_PUBLIC_DONATION_VAULT_CONTRACT_ID
ENV NEXT_PUBLIC_NGO_REGISTRY_CONTRACT_ID=$NEXT_PUBLIC_NGO_REGISTRY_CONTRACT_ID
ENV NEXT_PUBLIC_USDC_ISSUER=$NEXT_PUBLIC_USDC_ISSUER

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

# ---- runtime: minimal standalone server, non-root ----
FROM node:22-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production
ENV PORT=3001

RUN addgroup --system --gid 1001 nodejs \
  && adduser --system --uid 1001 --ingroup nodejs streamgive

# output: 'standalone' (next.config.ts) produces a self-contained server
# bundle, but deliberately excludes public/ and .next/static — Next's own
# docs call out copying those two alongside it by hand.
COPY --from=build --chown=streamgive:nodejs /app/.next/standalone ./
COPY --from=build --chown=streamgive:nodejs /app/.next/static ./.next/static
COPY --from=build --chown=streamgive:nodejs /app/public ./public

USER streamgive

EXPOSE 3001
CMD ["node", "server.js"]
